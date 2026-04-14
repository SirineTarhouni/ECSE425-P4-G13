library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_unit_tb is
end entity control_unit_tb;

architecture behavioral of control_unit_tb is

    signal instruction : std_logic_vector(31 downto 0) := (others => '0');

    signal alu_op     : std_logic_vector(3 downto 0);
    signal alu_src    : std_logic;
    signal mem_read   : std_logic;
    signal mem_write  : std_logic;
    signal reg_write  : std_logic;
    signal mem_to_reg : std_logic;
    signal branch     : std_logic;
    signal jump       : std_logic;
    signal jump_reg   : std_logic;
    signal pc_src     : std_logic;
    signal mem_size   : std_logic_vector(1 downto 0);
    signal mem_signed : std_logic;

    -- ALU op codes
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

    function r_type(
        funct7 : std_logic_vector(6 downto 0);
        funct3 : std_logic_vector(2 downto 0);
        opcode : std_logic_vector(6 downto 0)
    ) return std_logic_vector is
    begin
        -- rs2=x2 (00010), rs1=x1 (00001), rd=x3 (00011)
        return funct7 & "00010" & "00001" & funct3 & "00011" & opcode;
    end function;

    -- build an I-type instruction word
    function i_type(
        imm    : std_logic_vector(11 downto 0);
        funct3 : std_logic_vector(2 downto 0);
        opcode : std_logic_vector(6 downto 0)
    ) return std_logic_vector is
    begin
        -- rs1=x1 (00001), rd=x3 (00011)
        return imm & "00001" & funct3 & "00011" & opcode;
    end function;

    -- build a minimal instruction with just an opcode
    -- (used for jal, lui, auipc, only check opcode decoding)
    function opcode_only(
        opcode : std_logic_vector(6 downto 0)
    ) return std_logic_vector is
    begin
        return (31 downto 7 => '0') & opcode;
    end function;

    procedure check1(
        test_name : in string;
        got       : in std_logic;
        expected  : in std_logic
    ) is
    begin
        if got = expected then
            report "PASS: " & test_name severity note;
        else
            report "FAIL: " & test_name &
                   "  got="      & std_logic'image(got) &
                   "  expected=" & std_logic'image(expected)
                   severity error;
        end if;
    end procedure;

    procedure checkv(
        test_name : in string;
        got       : in std_logic_vector;
        expected  : in std_logic_vector
    ) is
    begin
        if got = expected then
            report "PASS: " & test_name severity note;
        else
            report "FAIL: " & test_name &
                   "  got="      & integer'image(to_integer(unsigned(got))) &
                   "  expected=" & integer'image(to_integer(unsigned(expected)))
                   severity error;
        end if;
    end procedure;

begin

    uut: entity work.control_unit
        port map (
            instruction => instruction,
            alu_op      => alu_op,
            alu_src     => alu_src,
            mem_read    => mem_read,
            mem_write   => mem_write,
            reg_write   => reg_write,
            mem_to_reg  => mem_to_reg,
            branch      => branch,
            jump        => jump,
            jump_reg    => jump_reg,
            pc_src      => pc_src,
            mem_size    => mem_size,
            mem_signed  => mem_signed
        );

    -- Test process
    process
    begin

        -- R-TYPE instructions  (opcode = 0110011)
        -- Expected: alu_src=0, reg_write=1, all memory/branch/jump = 0

        -- ADD
        instruction <= r_type("0000000", "000", "0110011");
        wait for 10 ns;
        report "--- R-type: ADD ---" severity note;
        checkv("ADD alu_op",    alu_op,    ALU_ADD);
        check1("ADD alu_src",   alu_src,   '0');
        check1("ADD reg_write", reg_write, '1');
        check1("ADD mem_read",  mem_read,  '0');
        check1("ADD mem_write", mem_write, '0');
        check1("ADD branch",    branch,    '0');
        check1("ADD jump",      jump,      '0');

        -- SUB 
        instruction <= r_type("0100000", "000", "0110011");
        wait for 10 ns;
        report "--- R-type: SUB ---" severity note;
        checkv("SUB alu_op",    alu_op,    ALU_SUB);
        check1("SUB alu_src",   alu_src,   '0');
        check1("SUB reg_write", reg_write, '1');

        -- MUL
        instruction <= r_type("0000001", "000", "0110011");
        wait for 10 ns;
        report "--- R-type: MUL ---" severity note;
        checkv("MUL alu_op",    alu_op,    ALU_MUL);
        check1("MUL reg_write", reg_write, '1');
        check1("MUL alu_src",   alu_src,   '0');

        -- AND
        instruction <= r_type("0000000", "111", "0110011");
        wait for 10 ns;
        report "--- R-type: AND ---" severity note;
        checkv("AND alu_op", alu_op, ALU_AND);
        check1("AND reg_write", reg_write, '1');

        -- OR
        instruction <= r_type("0000000", "110", "0110011");
        wait for 10 ns;
        report "--- R-type: OR ---" severity note;
        checkv("OR alu_op", alu_op, ALU_OR);

        -- XOR
        instruction <= r_type("0000000", "100", "0110011");
        wait for 10 ns;
        report "--- R-type: XOR ---" severity note;
        checkv("XOR alu_op", alu_op, ALU_XOR);

        -- SLL
        instruction <= r_type("0000000", "001", "0110011");
        wait for 10 ns;
        report "--- R-type: SLL ---" severity note;
        checkv("SLL alu_op", alu_op, ALU_SLL);

        -- SRL
        instruction <= r_type("0000000", "101", "0110011");
        wait for 10 ns;
        report "--- R-type: SRL ---" severity note;
        checkv("SRL alu_op", alu_op, ALU_SRL);

        -- SRA
        instruction <= r_type("0100000", "101", "0110011");
        wait for 10 ns;
        report "--- R-type: SRA ---" severity note;
        checkv("SRA alu_op", alu_op, ALU_SRA);

        -- SLT
        instruction <= r_type("0000000", "010", "0110011");
        wait for 10 ns;
        report "--- R-type: SLT ---" severity note;
        checkv("SLT alu_op", alu_op, ALU_SLT);

        -- SLTU
        instruction <= r_type("0000000", "011", "0110011");
        wait for 10 ns;
        report "--- R-type: SLTU ---" severity note;
        checkv("SLTU alu_op", alu_op, ALU_SLTU);

        -- I-TYPE ALU instructions  (opcode = 0010011)
        -- Expected: alu_src=1, reg_write=1, memory/branch/jump = 0

        -- ADDI
        instruction <= i_type("000000000001", "000", "0010011");
        wait for 10 ns;
        report "--- I-type: ADDI ---" severity note;
        checkv("ADDI alu_op",    alu_op,    ALU_ADD);
        check1("ADDI alu_src",   alu_src,   '1');
        check1("ADDI reg_write", reg_write, '1');
        check1("ADDI mem_read",  mem_read,  '0');
        check1("ADDI branch",    branch,    '0');

        -- XORI
        instruction <= i_type("000000000001", "100", "0010011");
        wait for 10 ns;
        report "--- I-type: XORI ---" severity note;
        checkv("XORI alu_op",  alu_op,  ALU_XOR);
        check1("XORI alu_src", alu_src, '1');

        -- ORI
        instruction <= i_type("000000000001", "110", "0010011");
        wait for 10 ns;
        report "--- I-type: ORI ---" severity note;
        checkv("ORI alu_op", alu_op, ALU_OR);

        -- ANDI
        instruction <= i_type("000000000001", "111", "0010011");
        wait for 10 ns;
        report "--- I-type: ANDI ---" severity note;
        checkv("ANDI alu_op", alu_op, ALU_AND);

        -- SLLI
        -- funct7=0000000 lives in imm[11:5] for shift immediates
        instruction <= i_type("000000000100", "001", "0010011");
        wait for 10 ns;
        report "--- I-type: SLLI ---" severity note;
        checkv("SLLI alu_op", alu_op, ALU_SLL);

        -- SRLI
        instruction <= i_type("000000000010", "101", "0010011");
        wait for 10 ns;
        report "--- I-type: SRLI ---" severity note;
        checkv("SRLI alu_op", alu_op, ALU_SRL);

        -- SRAI
        -- funct7 = 0100000 → imm[11:5] = 0100000
        instruction <= i_type("010000000010", "101", "0010011");
        wait for 10 ns;
        report "--- I-type: SRAI ---" severity note;
        checkv("SRAI alu_op", alu_op, ALU_SRA);

        -- SLTI
        instruction <= i_type("000000000001", "010", "0010011");
        wait for 10 ns;
        report "--- I-type: SLTI ---" severity note;
        checkv("SLTI alu_op", alu_op, ALU_SLT);

        -- SLTIU
        instruction <= i_type("000000000001", "011", "0010011");
        wait for 10 ns;
        report "--- I-type: SLTIU ---" severity note;
        checkv("SLTIU alu_op", alu_op, ALU_SLTU);

        -- LOAD instructions  (opcode = 0000011)
        -- Expected: alu_src=1, mem_read=1, reg_write=1, mem_to_reg=1, branch=0, jump=0

        -- LW
        instruction <= i_type("000000000100", "010", "0000011");
        wait for 10 ns;
        report "--- LOAD: LW ---" severity note;
        checkv("LW alu_op",      alu_op,      ALU_ADD);
        check1("LW alu_src",     alu_src,     '1');
        check1("LW mem_read",    mem_read,    '1');
        check1("LW reg_write",   reg_write,   '1');
        check1("LW mem_to_reg",  mem_to_reg,  '1');
        check1("LW mem_write",   mem_write,   '0');
        check1("LW branch",      branch,      '0');
        checkv("LW mem_size",    mem_size,    "10");
        check1("LW mem_signed",  mem_signed,  '1');

        -- LH
        instruction <= i_type("000000000100", "001", "0000011");
        wait for 10 ns;
        report "--- LOAD: LH ---" severity note;
        checkv("LH mem_size",   mem_size,   "01");
        check1("LH mem_signed", mem_signed, '1');

        -- LB
        instruction <= i_type("000000000100", "000", "0000011");
        wait for 10 ns;
        report "--- LOAD: LB ---" severity note;
        checkv("LB mem_size",   mem_size,   "00");
        check1("LB mem_signed", mem_signed, '1');

        -- LHU
        instruction <= i_type("000000000100", "101", "0000011");
        wait for 10 ns;
        report "--- LOAD: LHU ---" severity note;
        checkv("LHU mem_size",   mem_size,   "01");
        check1("LHU mem_signed", mem_signed, '0'); -- zero-extends

        -- LBU
        instruction <= i_type("000000000100", "100", "0000011");
        wait for 10 ns;
        report "--- LOAD: LBU ---" severity note;
        checkv("LBU mem_size",   mem_size,   "00");
        check1("LBU mem_signed", mem_signed, '0'); -- zero-extends

        -- STORE instructions  (opcode = 0100011)
        -- Expected: alu_src=1, mem_write=1, reg_write=0, mem_read=0, branch=0, jump=0

        -- SW
        -- S-type: imm[11:5] in [31:25], imm[4:0] in [11:7]
        -- funct3=010 (word) and imm=0
        instruction <= "0000000" & "00010" & "00001" & "010" & "00000" & "0100011";
        wait for 10 ns;
        report "--- STORE: SW ---" severity note;
        checkv("SW alu_op",    alu_op,    ALU_ADD);
        check1("SW alu_src",   alu_src,   '1');
        check1("SW mem_write", mem_write, '1');
        check1("SW reg_write", reg_write, '0');
        check1("SW mem_read",  mem_read,  '0');
        checkv("SW mem_size",  mem_size,  "10");

        -- SH
        instruction <= "0000000" & "00010" & "00001" & "001" & "00000" & "0100011";
        wait for 10 ns;
        report "--- STORE: SH ---" severity note;
        checkv("SH mem_size", mem_size, "01");
        check1("SH mem_write", mem_write, '1');

        -- SB
        instruction <= "0000000" & "00010" & "00001" & "000" & "00000" & "0100011";
        wait for 10 ns;
        report "--- STORE: SB ---" severity note;
        checkv("SB mem_size", mem_size, "00");
        check1("SB mem_write", mem_write, '1');

        -- BRANCH instructions  (opcode = 1100011)
        -- Expected: branch=1, pc_src=1, alu_src=1, reg_write=0, mem_read=0, mem_write=0, jump=0

        -- BEQ
        instruction <= "0000000" & "00010" & "00001" & "000" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BEQ ---" severity note;
        check1("BEQ branch",    branch,    '1');
        check1("BEQ pc_src",    pc_src,    '1');
        check1("BEQ alu_src",   alu_src,   '1');
        check1("BEQ reg_write", reg_write, '0');
        check1("BEQ mem_read",  mem_read,  '0');
        check1("BEQ jump",      jump,      '0');

        -- BNE
        instruction <= "0000000" & "00010" & "00001" & "001" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BNE ---" severity note;
        check1("BNE branch", branch, '1');
        check1("BNE pc_src", pc_src, '1');

        -- BLT
        instruction <= "0000000" & "00010" & "00001" & "100" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BLT ---" severity note;
        check1("BLT branch", branch, '1');

        -- BGE
        instruction <= "0000000" & "00010" & "00001" & "101" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BGE ---" severity note;
        check1("BGE branch", branch, '1');

        -- BLTU
        instruction <= "0000000" & "00010" & "00001" & "110" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BLTU ---" severity note;
        check1("BLTU branch", branch, '1');

        -- BGEU
        instruction <= "0000000" & "00010" & "00001" & "111" & "00000" & "1100011";
        wait for 10 ns;
        report "--- BRANCH: BGEU ---" severity note;
        check1("BGEU branch", branch, '1');

        -- JAL  (opcode = 1101111)
        -- Expected: jump=1, reg_write=1, pc_src=1, jump_reg=0, branch=0, mem_read=0, mem_write=0
        instruction <= opcode_only("1101111");
        wait for 10 ns;
        report "--- JAL ---" severity note;
        check1("JAL jump",      jump,      '1');
        check1("JAL reg_write", reg_write, '1');
        check1("JAL pc_src",    pc_src,    '1');
        check1("JAL jump_reg",  jump_reg,  '0');
        check1("JAL branch",    branch,    '0');

        -- JALR  (opcode = 1100111)
        -- Expected: jump=1, jump_reg=1, reg_write=1, pc_src=0 (target = rs1+imm not PC+imm), branch=0
        instruction <= i_type("000000000000", "000", "1100111");
        wait for 10 ns;
        report "--- JALR ---" severity note;
        check1("JALR jump",      jump,      '1');
        check1("JALR jump_reg",  jump_reg,  '1');
        check1("JALR reg_write", reg_write, '1');
        check1("JALR pc_src",    pc_src,    '0'); -- rs1, not PC
        check1("JALR branch",    branch,    '0');

        -- LUI  (opcode = 0110111)
        -- Expected: alu_op=LUI, alu_src=1, reg_write=1, all others 0
        instruction <= opcode_only("0110111");
        wait for 10 ns;
        report "--- LUI ---" severity note;
        checkv("LUI alu_op",    alu_op,    ALU_LUI);
        check1("LUI alu_src",   alu_src,   '1');
        check1("LUI reg_write", reg_write, '1');
        check1("LUI branch",    branch,    '0');
        check1("LUI jump",      jump,      '0');
        check1("LUI mem_read",  mem_read,  '0');

        -- AUIPC  (opcode = 0010111)
        -- Expected: alu_op=ADD, alu_src=1, pc_src=1, reg_write=1, branch=0, jump=0
        instruction <= opcode_only("0010111");
        wait for 10 ns;
        report "--- AUIPC ---" severity note;
        checkv("AUIPC alu_op",    alu_op,    ALU_ADD);
        check1("AUIPC alu_src",   alu_src,   '1');
        check1("AUIPC pc_src",    pc_src,    '1');
        check1("AUIPC reg_write", reg_write, '1');
        check1("AUIPC branch",    branch,    '0');
        check1("AUIPC jump",      jump,      '0');

        -- NOP / unknown opcode, all control signals must be 0
        -- (tests the default branch in the case statement)
        instruction <= (others => '0'); -- opcode = 0000000 (invalid)
        wait for 10 ns;
        report "--- NOP / unknown opcode ---" severity note;
        check1("NOP reg_write", reg_write, '0');
        check1("NOP mem_read",  mem_read,  '0');
        check1("NOP mem_write", mem_write, '0');
        check1("NOP branch",    branch,    '0');
        check1("NOP jump",      jump,      '0');

        report "All tests done." severity note;

        wait;
    end process;

end architecture behavioral;

