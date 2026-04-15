-- INPUTS:
--     instruction : full 32-bit instruction word (from IF/ID.IR)
--
-- OUTPUTS:
--    alu_op      : 4-bit ALU operation code
--    alu_src     : selects ALU op_b source
--        '0' = register (rs2)
--        '1' = immediate
--    mem_read    : '1' instruction reads data memory (loads)
--    mem_write   : '1' instruction writes data memory (stores)
--    reg_write   : '1' instruction writes a register (rd)
--    mem_to_reg  : selects writeback source
--        '0' = ALU result
--        '1' = data memory (load)
--    branch      : '1' instruction is a branch
--    jump        : '1' instruction is jal or jalr
--    jump_reg    : '1' for jalr (target = rs1+imm)
--    pc_src      : selects op_a for ALU
--        '0' = rs1
--        '1' = PC  (for auipc, jal)
--    mem_size    : 2-bit data memory access width
--        "00" = byte, "01" = halfword, "10" = word
--    mem_signed  : '1' load sign-extends (lb, lh)
--        '0' load zero-extends (lbu, lhu)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit is
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
end entity control_unit;

architecture behavioral of control_unit is

    -- this extract the three fields that drive all decoding
    alias opcode : std_logic_vector(6 downto 0) is instruction(6 downto 0);
    alias funct3 : std_logic_vector(2 downto 0) is instruction(14 downto 12);
    alias funct7 : std_logic_vector(6 downto 0) is instruction(31 downto 25);


    -- Opcode constants
    constant OP_R      : std_logic_vector(6 downto 0) := "0110011"; -- R-type  (add, sub, mul, ...)
    constant OP_I_ALU  : std_logic_vector(6 downto 0) := "0010011"; -- I-type  (addi, xori, ...)
    constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011"; -- loads   (lb, lh, lw, ...)
    constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011"; -- stores  (sb, sh, sw)
    constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011"; -- branches(beq, bne, ...)
    constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111"; -- jal
    constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111"; -- jalr
    constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111"; -- lui
    constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111"; -- auipc

    -- ALU operation codes (they match alu.vhd exactly)
    constant ALU_ADD  : std_logic_vector(3 downto 0) := "0000";
    constant ALU_SUB  : std_logic_vector(3 downto 0) := "0001";
    constant ALU_AND  : std_logic_vector(3 downto 0) := "0010";
    constant ALU_OR   : std_logic_vector(3 downto 0) := "0011";
    constant ALU_XOR  : std_logic_vector(3 downto 0) := "0100";
    constant ALU_SLL  : std_logic_vector(3 downto 0) := "0101";
    constant ALU_SRL  : std_logic_vector(3 downto 0) := "0110";
    constant ALU_SRA  : std_logic_vector(3 downto 0) := "0111";
    constant ALU_SLT  : std_logic_vector(3 downto 0) := "1000";
    constant ALU_SLTU : std_logic_vector(3 downto 0) := "1001";
    constant ALU_LUI  : std_logic_vector(3 downto 0) := "1010";
    constant ALU_MUL  : std_logic_vector(3 downto 0) := "1011";



begin

    process(instruction)
    begin
        alu_op     <= ALU_ADD;
        alu_src    <= '0';
        mem_read   <= '0';
        mem_write  <= '0';
        reg_write  <= '0';
        mem_to_reg <= '0';
        branch     <= '0';
        jump       <= '0';
        jump_reg   <= '0';
        pc_src     <= '0';
        mem_size   <= "10";
        mem_signed <= '1';



        case opcode is

            -- R-TYPE: add, sub, mul, and, or, xor, sll, srl, sra, slt, sltu
            -- op_a = rs1, op_b = rs2 (alu_src = '0')
            -- Result written to rd (reg_write = '1')
            -- funct7 distinguishe between add/sub/mul and srl/sra
            when OP_R =>
                alu_src   <= '0'; -- op_b comes from rs2
                reg_write <= '1';-- result goes to rd

                case funct3 is
                    when "000" => -- add, sub, or mul, we check for funct7
                        if    funct7 = "0000000" then alu_op <= ALU_ADD;
                        elsif funct7 = "0100000" then alu_op <= ALU_SUB;
                        elsif funct7 = "0000001" then alu_op <= ALU_MUL;
                        else                          alu_op <= ALU_ADD;
                        end if;
                    when "001" => alu_op <= ALU_SLL;
                    when "010" => alu_op <= ALU_SLT;
                    when "011" => alu_op <= ALU_SLTU;
                    when "100" => alu_op <= ALU_XOR;
                    when "101" => -- srl or sra we check for funct7
                        if funct7 = "0100000" then alu_op <= ALU_SRA;
                        else                       alu_op <= ALU_SRL;
                        end if;
                    when "110" => alu_op <= ALU_OR;
                    when "111" => alu_op <= ALU_AND;
                    when others => alu_op <= ALU_ADD;
                end case;

            -- I-TYPE ALU: addi, xori, ori, andi, slli, srli, srai, slti, sltiu
            -- op_a = rs1, op_b = sign-extended immediate (alu_src='1')
            -- Result written to rd
            -- For slli/srli/srai the shift amount is imm[4:0] and the ALU already extracts the low 5 bits of op_b
                    
            when OP_I_ALU =>
                alu_src   <= '1'; -- op_b comes from immediate
                reg_write <= '1';

                case funct3 is
                    when "000" => alu_op <= ALU_ADD;
                    when "100" => alu_op <= ALU_XOR;
                    when "110" => alu_op <= ALU_OR;
                    when "111" => alu_op <= ALU_AND;
                    when "001" => alu_op <= ALU_SLL;
                    when "101" => -- srli or srai,we check for funct7
                        if funct7 = "0100000" then alu_op <= ALU_SRA;
                        else                       alu_op <= ALU_SRL;
                        end if;
                    when "010" => alu_op <= ALU_SLT;
                    when "011" => alu_op <= ALU_SLTU;
                    when others => alu_op <= ALU_ADD;
                end case;

                    
            -- Loads: lb, lh, lw, lbu, lhu
            -- ALU computes address: rs1 + sign-extended imm
            -- Result comes from data memory-> mem_to_reg='1'
            -- mem_size and mem_signed: the memory unit reads and extends the loaded value
            when OP_LOAD =>
                alu_op     <= ALU_ADD; -- address = rs1 + imm
                alu_src    <= '1';-- immediate as op_b
                mem_read   <= '1';
                reg_write  <= '1';
                mem_to_reg <= '1';-- writeback from memory

                case funct3 is
                    when "000" => -- lb  : sign-extended byte
                        mem_size   <= "00";
                        mem_signed <= '1';
                    when "001" => -- lh  : sign-extended halfword
                        mem_size   <= "01";
                        mem_signed <= '1';
                    when "010" => -- lw  : full word
                        mem_size   <= "10";
                        mem_signed <= '1';
                    when "100" => -- lbu : zero-extended byte
                        mem_size   <= "00";
                        mem_signed <= '0';

                    when "101" => -- lhu : zero-extended halfword
                        mem_size   <= "01";
                        mem_signed <= '0';
                    when others =>
                        mem_size   <= "10";
                        mem_signed <= '1';
                end case;

                    
            -- STORES: sb, sh, sw
            -- ALU computes address: rs1 + sign-extended imm
            when OP_STORE =>
                alu_op    <= ALU_ADD;-- address = rs1 + imm
                alu_src   <= '1';-- immediate as op_b
                mem_write <= '1';

                case funct3 is
                    when "000"  => mem_size <= "00";-- sb
                    when "001"  => mem_size <= "01";-- sh
                    when "010"  => mem_size <= "10";-- sw
                    when others => mem_size <= "10";
                end case;

            -- BRANCHES: beq, bne, blt, bge, bltu, bgeu
            -- The branch comparator (in the EX stage) compares rs1 and rs2 directly and sets the cond signal
            -- the ALU does the branch target-> NPC + (imm << 1)
            -- branch='1' so the pipeline knows to check cond
            -- funct3 is passed through the pipeline register so the branch comparator knows which comparison to perform
            when OP_BRANCH =>
                alu_op  <= ALU_ADD; -- branch target = NPC + imm
                alu_src <= '1';-- immediate as op_b
                pc_src  <= '1';-- op_a = NPC (not rs1)
                branch  <= '1';
                -- reg_write stays '0', branches don't write rd

            -- JAL: jump and link
            -- rd = PC + 4  (return address)
            -- PC = PC + sign-extended imm (jump target)
            -- ALU computes jump target: PC + imm

            -- pc_src='1' routes PC into op_a
            -- The return address (PC+4 = NPC) is written to rd
            when OP_JAL =>
                alu_op    <= ALU_ADD;
                alu_src   <= '1';-- immediate as op_b
                pc_src    <= '1';-- op_a = PC
                reg_write <= '1';-- rd = PC+4
                jump      <= '1';


            -- JALR: jump and link register
            -- rd = PC + 4
            -- PC = (rs1 + imm) with bit 0 cleared 
            -- op_a = rs1 (not PC), so pc_src stays '0'
            -- jump_reg='1' lets the processor know to use ALUOut directly as the new PC
            when OP_JALR =>
                alu_op    <= ALU_ADD;
                alu_src   <= '1';-- immediate as op_b
                reg_write <= '1';-- rd = PC+4
                jump      <= '1';
                jump_reg  <= '1';-- target = rs1+imm, not PC+imm

            -- LUI: load upper immediate
            -- rd = imm << 12(immediate generator pre-shifts it)
            -- ALU just passes op_b (the shifted immediate) straight through using ALU_LUI
            -- op_a is irrelevant —> rs1 is not used.
            when OP_LUI =>
                alu_op    <= ALU_LUI;
                alu_src   <= '1';-- immediate as op_b
                reg_write <= '1';


            -- AUIPC: add upper immediate to PC
            -- rd = PC + (imm << 12)
            -- ALU computes PC + imm, so op_a must be PC
            -- pc_src='1' routes PC into op_a
            when OP_AUIPC =>
                alu_op    <= ALU_ADD;
                alu_src   <= '1';-- immediate as op_b
                pc_src    <= '1';-- op_a = PC
                reg_write <= '1';


            when others =>
                null;



        end case;
    end process;

end architecture behavioral;

