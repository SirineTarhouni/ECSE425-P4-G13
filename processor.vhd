-- Stages: IF → ID → EX → MEM → WB
--
-- the Pipelined registers between stages:
--   IF/ID:fetched instruction and NPC (PC+4)
--   ID/EX:decoded operands, immediate, control signals
--   EX/MEM:ALU result, store data, control signals
--   MEM/WB:holds ALU result or load data, control signals
--
-- Hazard detection stalls pipeline when a required operand is not available (RAW hazard)
-- A bubble (NOP = addi x0,x0,0 -> so it doenst do anyting) put in EX stage
--
-- Branch resolution in EX
-- taken branch causes 3-cycle penalty: 3 instructions fetched after branch are flushed (replaced with NOPs)
--
-- INPUTS:
--   clk   : the clock (synched)
--   reset : active-high synchronous reset

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity processor is
    port (
        clk   : in std_logic;
        reset : in std_logic
    );
end entity processor;

architecture behavioral of processor is

    -- COMPONENT DECLARATIONS
    component alu is
        port (
            op_a   : in  std_logic_vector(31 downto 0);
            op_b   : in  std_logic_vector(31 downto 0);
            alu_op : in  std_logic_vector(3 downto 0);
            result : out std_logic_vector(31 downto 0)
        );
    end component;

    component register_file is
        port (
            clk       : in  std_logic;
            rs1_addr  : in  std_logic_vector(4 downto 0);
            rs2_addr  : in  std_logic_vector(4 downto 0);
            rs1_data  : out std_logic_vector(31 downto 0);
            rs2_data  : out std_logic_vector(31 downto 0);
            rd_addr   : in  std_logic_vector(4 downto 0);
            rd_data   : in  std_logic_vector(31 downto 0);
            reg_write : in  std_logic
        );
    end component;

    component control_unit is
        port (
            instruction : in  std_logic_vector(31 downto 0);
            alu_op      : out std_logic_vector(3 downto 0);
            alu_src     : out std_logic;
            mem_read    : out std_logic;
            mem_write   : out std_logic;
            reg_write   : out std_logic;
            mem_to_reg  : out std_logic;
            branch      : out std_logic;
            jump        : out std_logic;
            jump_reg    : out std_logic;
            pc_src      : out std_logic;
            mem_size    : out std_logic_vector(1 downto 0);
            mem_signed  : out std_logic
        );
    end component;

    component imm_gen is
        port (
            instruction : in  std_logic_vector(31 downto 0);
            imm_out     : out std_logic_vector(31 downto 0)
        );
    end component;

    component instruction_mem is
        port (
            clk             : in  std_logic;
            address         : in  std_logic_vector(31 downto 0);
            instruction_out : out std_logic_vector(31 downto 0)
        );
    end component;

    component data_mem is
        port (
            clk        : in  std_logic;
            address    : in  std_logic_vector(31 downto 0);
            write_data : in  std_logic_vector(31 downto 0);
            mem_read   : in  std_logic;
            mem_write  : in  std_logic;
            mem_size   : in  std_logic_vector(1 downto 0);
            mem_signed : in  std_logic;
            read_data  : out std_logic_vector(31 downto 0)
        );
    end component;

    -- NOP = addi x0, x0, 0 -> (opcode=0010011, funct3=000, rd=0, rs1=0, imm=0) -> this is its corresponding instruciotn
    constant NOP : std_logic_vector(31 downto 0) := x"00000013";

    -- IF STAGE SIGNALS
    signal pc          : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4    : std_logic_vector(31 downto 0);
    signal next_pc     : std_logic_vector(31 downto 0);
    signal instr_if    : std_logic_vector(31 downto 0); -- raw output of instruction memory

    -- IF/ID PIPELINE REGISTER
    signal ifid_ir  : std_logic_vector(31 downto 0) := (others => '0'); -- instruction
    signal ifid_npc : std_logic_vector(31 downto 0) := (others => '0'); -- PC+4

    -- ID STAGE SIGNALS
    -- Control signals decoded from ifid_ir
    signal cu_alu_op     : std_logic_vector(3 downto 0);
    signal cu_alu_src    : std_logic;
    signal cu_mem_read   : std_logic;
    signal cu_mem_write  : std_logic;
    signal cu_reg_write  : std_logic;
    signal cu_mem_to_reg : std_logic;
    signal cu_branch     : std_logic;
    signal cu_jump       : std_logic;
    signal cu_jump_reg   : std_logic;
    signal cu_pc_src     : std_logic;
    signal cu_mem_size   : std_logic_vector(1 downto 0);
    signal cu_mem_signed : std_logic;

    -- Register file read data
    signal rf_rs1_data : std_logic_vector(31 downto 0);
    signal rf_rs2_data : std_logic_vector(31 downto 0);

    -- Immediate generator output
    signal imm_id : std_logic_vector(31 downto 0);

    -- Register addresses extracted from instruction
    alias id_rs1 : std_logic_vector(4 downto 0) is ifid_ir(19 downto 15);
    alias id_rs2 : std_logic_vector(4 downto 0) is ifid_ir(24 downto 20);
    alias id_rd  : std_logic_vector(4 downto 0) is ifid_ir(11 downto  7);

    -- ID/EX PIPELINE REGISTER
    signal idex_npc        : std_logic_vector(31 downto 0) := (others => '0');
    signal idex_ir         : std_logic_vector(31 downto 0) := (others => '0');
    signal idex_a          : std_logic_vector(31 downto 0) := (others => '0'); -- rs1 value
    signal idex_b          : std_logic_vector(31 downto 0) := (others => '0'); -- rs2 value
    signal idex_imm        : std_logic_vector(31 downto 0) := (others => '0');
    -- Control signals carried forward
    signal idex_alu_op     : std_logic_vector(3 downto 0)  := (others => '0');
    signal idex_alu_src    : std_logic := '0';
    signal idex_mem_read   : std_logic := '0';
    signal idex_mem_write  : std_logic := '0';
    signal idex_reg_write  : std_logic := '0';
    signal idex_mem_to_reg : std_logic := '0';
    signal idex_branch     : std_logic := '0';
    signal idex_jump       : std_logic := '0';
    signal idex_jump_reg   : std_logic := '0';
    signal idex_pc_src     : std_logic := '0';
    signal idex_mem_size   : std_logic_vector(1 downto 0) := (others => '0');
    signal idex_mem_signed : std_logic := '1';

    -- EX STAGE SIGNALS
    -- ALU inputs (after muxes)
    signal alu_op_a   : std_logic_vector(31 downto 0);
    signal alu_op_b   : std_logic_vector(31 downto 0);
    signal alu_result : std_logic_vector(31 downto 0);

    -- Branch comparator
    signal branch_cond : std_logic; -- '1' if branch should be taken

    -- Branch/jump target address
    signal branch_target : std_logic_vector(31 downto 0);

    -- Register addresses in EX (from ID/EX.IR)
    alias ex_rd  : std_logic_vector(4 downto 0) is idex_ir(11 downto  7);
    alias ex_rs1 : std_logic_vector(4 downto 0) is idex_ir(19 downto 15);
    alias ex_rs2 : std_logic_vector(4 downto 0) is idex_ir(24 downto 20);
    alias ex_f3  : std_logic_vector(2 downto 0) is idex_ir(14 downto 12); -- funct3 for branch type

     
    -- EX/MEM PIPELINE REGISTER
    signal exmem_ir         : std_logic_vector(31 downto 0) := (others => '0');
    signal exmem_alu_out    : std_logic_vector(31 downto 0) := (others => '0');
    signal exmem_b          : std_logic_vector(31 downto 0) := (others => '0'); -- store data
    signal exmem_cond       : std_logic := '0';   -- branch taken?
    signal exmem_branch_tgt : std_logic_vector(31 downto 0) := (others => '0');
    -- Control signals
    signal exmem_mem_read   : std_logic := '0';
    signal exmem_mem_write  : std_logic := '0';
    signal exmem_reg_write  : std_logic := '0';
    signal exmem_mem_to_reg : std_logic := '0';
    signal exmem_branch     : std_logic := '0';
    signal exmem_jump       : std_logic := '0';
    signal exmem_mem_size   : std_logic_vector(1 downto 0) := (others => '0');
    signal exmem_mem_signed : std_logic := '1';
    signal exmem_npc        : std_logic_vector(31 downto 0) := (others => '0'); -- for jal/jalr writeback

    -- MEM STAGE SIGNALS
    signal mem_read_data : std_logic_vector(31 downto 0); -- data memory output

    -- Register address in MEM (from EX/MEM.IR)
    alias mem_rd : std_logic_vector(4 downto 0) is exmem_ir(11 downto 7);

     
    -- MEM/WB PIPELINE REGISTER
    signal memwb_ir         : std_logic_vector(31 downto 0) := (others => '0');
    signal memwb_alu_out    : std_logic_vector(31 downto 0) := (others => '0');
    signal memwb_lmd        : std_logic_vector(31 downto 0) := (others => '0'); -- load memory data
    signal memwb_npc        : std_logic_vector(31 downto 0) := (others => '0'); -- for jal/jalr
    -- Control signals
    signal memwb_reg_write  : std_logic := '0';
    signal memwb_mem_to_reg : std_logic := '0';
    signal memwb_jump       : std_logic := '0';

    -- WB STAGE SIGNALS
    signal wb_data    : std_logic_vector(31 downto 0); -- final writeback value
    signal wb_rd_addr : std_logic_vector(4 downto 0);  -- destination register

     
    -- HAZARD DETECTION SIGNALS
    signal stall       : std_logic; -- '1' = stall IF and ID, insert bubble into EX
    signal flush_ex    : std_logic; -- '1' = flush ID/EX (insert NOP into EX)
    signal flush_ifid  : std_logic; -- '1' = flush IF/ID (branch taken penalty)

     
    -- PC CONTROL

    -- Branch taken = branch instruction in MEM stage with cond='1'
    signal branch_taken : std_logic;

begin

     
    -- PC+4 ADDER
    pc_plus4 <= std_logic_vector(unsigned(pc) + 4);

     
    -- BRANCH TAKEN DETECTION -> it resolves in EX, and updates PC in mem stage  
    branch_taken <= exmem_branch and exmem_cond;

     
    -- NEXT PC MUX
    -- Priority: branch/jump overrides normal PC+4
    -- Jump: target is always taken (jal/jalr)
    -- Branch: target taken only when cond='1'
    next_pc <= exmem_branch_tgt when (branch_taken = '1' or exmem_jump = '1')
               else pc_plus4;

    -- PC REGISTER
    -- Stalls hold PC (and IF/ID) when hazard detected
    -- process cuz it acutally takes time and is synched
    pc_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc <= (others => '0');
            elsif stall = '0' and branch_taken = '0' and exmem_jump = '0' then
                pc <= pc_plus4;
            elsif branch_taken = '1' or exmem_jump = '1' then
                pc <= exmem_branch_tgt;
            -- else stall: PC holds its value
            end if;
        end if;
    end process pc_reg;

     
    -- INSTRUCTION MEMORY
    imem : instruction_mem
        port map (
            clk             => clk,
            address         => pc,
            instruction_out => instr_if
        );

    -- IF/ID PIPELINE REGISTER
    -- if Stall: hold current values
    -- if Flush (branch taken): we insert NOPs
    ifid_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush_ifid = '1' then
                ifid_ir  <= NOP;
                ifid_npc <= (others => '0');
            elsif stall = '0' then
                ifid_ir  <= instr_if;
                ifid_npc <= pc_plus4;
            -- else stall: IF/ID holds its value
            end if;
        end if;
    end process ifid_reg;

    -- FLUSH SIGNALS
    --if flush_ifid: squash the instruction in IF/ID on branch taken
    -- if flush_ex:   squash ID/EX on stall or branch (insert bubble)
    flush_ifid <= branch_taken or exmem_jump;
    flush_ex   <= stall or branch_taken or exmem_jump;


    -- CONTROL UNIT (ID stage)
    cu : control_unit
        port map (
            instruction => ifid_ir,
            alu_op      => cu_alu_op,
            alu_src     => cu_alu_src,
            mem_read    => cu_mem_read,
            mem_write   => cu_mem_write,
            reg_write   => cu_reg_write,
            mem_to_reg  => cu_mem_to_reg,
            branch      => cu_branch,
            jump        => cu_jump,
            jump_reg    => cu_jump_reg,
            pc_src      => cu_pc_src,
            mem_size    => cu_mem_size,
            mem_signed  => cu_mem_signed
        );

    -- IMMEDIATE GENERATOR (ID stage)
    ig : imm_gen
        port map (
            instruction => ifid_ir,
            imm_out     => imm_id
        );
    -- REGISTER FILE (ID stage reads, WB stage writes)
    rf : register_file
        port map (
            clk       => clk,
            rs1_addr  => id_rs1,
            rs2_addr  => id_rs2,
            rs1_data  => rf_rs1_data,
            rs2_data  => rf_rs2_data,
            rd_addr   => wb_rd_addr,
            rd_data   => wb_data,
            reg_write => memwb_reg_write
        );

    -- HAZARD DETECTION UNIT
    -- Note: stalls when instructoin in EX is load + desitination register matches src reg of instruction in ID -> load-use hazard
    -- Stall for RAW hazard (no forwarding) when instruction in EX is writing a reg + reg is a source reg of instruction in ID
    hazard : process(idex_reg_write, idex_mem_read,
                     ex_rd, id_rs1, id_rs2,
                     exmem_reg_write, mem_rd,
                     cu_mem_read, cu_mem_write, cu_branch, cu_jump)
        variable ex_writes_rd   : boolean;
        variable mem_writes_rd  : boolean;
        variable id_uses_ex_rd  : boolean;
        variable id_uses_mem_rd : boolean;
    begin
        -- insturciton in EX write a non zero register
        ex_writes_rd  := (idex_reg_write = '1') and (ex_rd /= "00000");

        -- instruciotn in MEM write non zero reg
        mem_writes_rd := (exmem_reg_write = '1') and (mem_rd /= "00000");

        -- instrciont in ID read rs1 or rs2 from EX's dest register
        id_uses_ex_rd := ex_writes_rd and ((id_rs1 = ex_rd) or (id_rs2 = ex_rd));

        -- instruoion in ID read rs1 or rs2 from MEM's dest register
        id_uses_mem_rd := mem_writes_rd and ((id_rs1 = mem_rd) or (id_rs2 = mem_rd));

        -- Stall if there is any unresolved RAW issues
        if id_uses_ex_rd or id_uses_mem_rd then
            stall <= '1';
        else
            stall <= '0';
        end if;
    end process hazard;

     
    -- ID/EX PIPELINE REGISTER
    -- Flush (stall or branch): insert NOP ctrl signals
    idex_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' or flush_ex = '1' then
                -- Insert NOP bubble (rest all 0)
                idex_ir         <= NOP;
                idex_npc        <= (others => '0');
                idex_a          <= (others => '0');
                idex_b          <= (others => '0');
                idex_imm        <= (others => '0');
                idex_alu_op     <= (others => '0');
                idex_alu_src    <= '0';
                idex_mem_read   <= '0';
                idex_mem_write  <= '0';
                idex_reg_write  <= '0';
                idex_mem_to_reg <= '0';
                idex_branch     <= '0';
                idex_jump       <= '0';
                idex_jump_reg   <= '0';
                idex_pc_src     <= '0';
                idex_mem_size   <= "10";
                idex_mem_signed <= '1';
            else
                idex_ir         <= ifid_ir;
                idex_npc        <= ifid_npc;
                idex_a          <= rf_rs1_data;
                idex_b          <= rf_rs2_data;
                idex_imm        <= imm_id;
                idex_alu_op     <= cu_alu_op;
                idex_alu_src    <= cu_alu_src;
                idex_mem_read   <= cu_mem_read;
                idex_mem_write  <= cu_mem_write;
                idex_reg_write  <= cu_reg_write;
                idex_mem_to_reg <= cu_mem_to_reg;
                idex_branch     <= cu_branch;
                idex_jump       <= cu_jump;
                idex_jump_reg   <= cu_jump_reg;
                idex_pc_src     <= cu_pc_src;
                idex_mem_size   <= cu_mem_size;
                idex_mem_signed <= cu_mem_signed;
            end if;
        end if;
    end process idex_reg;

     
    -- EX STAGE — ALU INPUT MUXES
    -- op_a mux: '0' = rs1 value, '1' = NPC (for auipc/jal)
    -- op_b mux: '0' = rs2 value, '1' = immediate
    alu_op_a <= idex_npc when idex_pc_src = '1' else idex_a;
    alu_op_b <= idex_imm when idex_alu_src = '1' else idex_b;

     
    -- ALU INSTANTIATION
    alu_inst : alu
        port map (
            op_a   => alu_op_a,
            op_b   => alu_op_b,
            alu_op => idex_alu_op,
            result => alu_result
        );

     
    -- BRANCH COMPARATOR
    -- Compares rs1 and rs2 based on funct3 to check if branch should be taken or not
    -- beq=000, bne=001, blt=100, bge=101, bltu=110, bgeu=111
    branch_compare : process(idex_a, idex_b, ex_f3, idex_branch)
        variable a_s : signed(31 downto 0);
        variable b_s : signed(31 downto 0);
        variable a_u : unsigned(31 downto 0);
        variable b_u : unsigned(31 downto 0);
    begin
        a_s := signed(idex_a);
        b_s := signed(idex_b);
        a_u := unsigned(idex_a);
        b_u := unsigned(idex_b);

        branch_cond <= '0'; -- default: not taken

        if idex_branch = '1' then
            case ex_f3 is
                when "000" => if a_s =  b_s  then branch_cond <= '1'; end if; -- beq
                when "001" => if a_s /= b_s  then branch_cond <= '1'; end if; -- bne
                when "100" => if a_s <  b_s  then branch_cond <= '1'; end if; -- blt
                when "101" => if a_s >= b_s  then branch_cond <= '1'; end if; -- bge
                when "110" => if a_u <  b_u  then branch_cond <= '1'; end if; -- bltu
                when "111" => if a_u >= b_u  then branch_cond <= '1'; end if; -- bgeu
                when others => branch_cond <= '0';
            end case;
        end if;
    end process branch_compare;

     
    -- BRANCH / JUMP TARGET ADDRESS
    -- for branches and jal: target = NPC + (imm << 1)
    -- since imm from imm_gen.vhd already deals iwth the bit shift (and sign extension), we can just add it to NPC
    -- note: NPC = PC+4 and its stored in ID/EX.NPC

    -- For jalr: target = (rs1 + imm) & 0xFFFFFFFE (clear bit 0)
    --  ----> This is just alu_result with bit 0 set to 0
    branch_target <= std_logic_vector(unsigned(idex_npc) + unsigned(idex_imm)) when idex_jump_reg = '0' else alu_result(31 downto 1) & '0'; -- jalr: clear bit 0

     
    -- EX/MEM PIPELINE REGISTER
    exmem_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                exmem_ir         <= NOP;
                exmem_alu_out    <= (others => '0');
                exmem_b          <= (others => '0');
                exmem_cond       <= '0';
                exmem_branch_tgt <= (others => '0');
                exmem_mem_read   <= '0';
                exmem_mem_write  <= '0';
                exmem_reg_write  <= '0';
                exmem_mem_to_reg <= '0';
                exmem_branch     <= '0';
                exmem_jump       <= '0';
                exmem_mem_size   <= "10";
                exmem_mem_signed <= '1';
                exmem_npc        <= (others => '0');
            else
                exmem_ir         <= idex_ir;
                exmem_alu_out    <= alu_result;
                exmem_b          <= idex_b;       -- rs2 value for stores
                exmem_cond       <= branch_cond;
                exmem_branch_tgt <= branch_target;
                exmem_mem_read   <= idex_mem_read;
                exmem_mem_write  <= idex_mem_write;
                exmem_reg_write  <= idex_reg_write;
                exmem_mem_to_reg <= idex_mem_to_reg;
                exmem_branch     <= idex_branch;
                exmem_jump       <= idex_jump;
                exmem_mem_size   <= idex_mem_size;
                exmem_mem_signed <= idex_mem_signed;
                exmem_npc        <= idex_npc;     -- PC+4 for jal/jalr writeback
            end if;
        end if;
    end process exmem_reg;

     
    -- DATA MEMORY (MEM stage)
    dmem : data_mem
        port map (
            clk        => clk,
            address    => exmem_alu_out,
            write_data => exmem_b,
            mem_read   => exmem_mem_read,
            mem_write  => exmem_mem_write,
            mem_size   => exmem_mem_size,
            mem_signed => exmem_mem_signed,
            read_data  => mem_read_data
        );

     
    -- MEM/WB PIPELINE REGISTER
    memwb_reg : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                memwb_ir         <= NOP;
                memwb_alu_out    <= (others => '0');
                memwb_lmd        <= (others => '0');
                memwb_npc        <= (others => '0');
                memwb_reg_write  <= '0';
                memwb_mem_to_reg <= '0';
                memwb_jump       <= '0';
            else
                memwb_ir         <= exmem_ir;
                memwb_alu_out    <= exmem_alu_out;
                memwb_lmd        <= mem_read_data;
                memwb_npc        <= exmem_npc;
                memwb_reg_write  <= exmem_reg_write;
                memwb_mem_to_reg <= exmem_mem_to_reg;
                memwb_jump       <= exmem_jump;
            end if;
        end if;
    end process memwb_reg;

     
    -- WB STAGE — WRITEBACK MUX
    --3 sources for what gets written to rd:
    --  1.  jump=1       : NPC (PC+4) — return address for jal/jalr
    --   2. mem_to_reg=1 : load data from memory
    --  3. default      : ALU result
    wb_data <= memwb_npc     when memwb_jump = '1'       else
               memwb_lmd     when memwb_mem_to_reg = '1' else
               memwb_alu_out;

    -- dest reg address from MEM/WB.IR
    wb_rd_addr <= memwb_ir(11 downto 7);

end architecture behavioral;
