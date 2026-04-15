library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity imm_gen_tb is
end entity imm_gen_tb;

architecture behavioral of imm_gen_tb is

    component imm_gen is
        port (
            instruction : in  std_logic_vector(31 downto 0);
            imm_out     : out std_logic_vector(31 downto 0)
        );
    end component;

    signal instruction : std_logic_vector(31 downto 0) := (others => '0');
    signal imm_out     : std_logic_vector(31 downto 0);

    -- Track overall pass/fail across all cases.
    shared variable all_pass : boolean := true;

    -- there might be a small delay between stimulus changes so combinational output settles before we sample it.
    constant T_SETTLE : time := 10 ns;

begin
    dut : imm_gen
        port map (
            instruction => instruction,
            imm_out     => imm_out
        );

    stimulus : process
        procedure check_imm (
            test_name   : in string;
            instr       : in std_logic_vector(31 downto 0);
            expected    : in std_logic_vector(31 downto 0)
        ) is
        begin
            instruction <= instr;
            wait for T_SETTLE;

            if imm_out = expected then
                report "[PASS] " & test_name severity note;
            else
                report "[FAIL] " & test_name
                     & "  expected=0x" & to_hstring(expected)
                     & "  got=0x"      & to_hstring(imm_out)
                     severity error;
                all_pass := false;
            end if;
        end procedure;

        -- I-type: [31:20]=imm[11:0], [19:15]=rs1, [14:12]=funct3, [11:7]=rd, [6:0]=opcode
        function encode_I (
            imm    : std_logic_vector(11 downto 0);
            rs1    : std_logic_vector(4  downto 0);
            funct3 : std_logic_vector(2  downto 0);
            rd     : std_logic_vector(4  downto 0);
            opcode : std_logic_vector(6  downto 0)
        ) return std_logic_vector is
        begin
            return imm & rs1 & funct3 & rd & opcode;
        end function;

        -- S-type: [31:25]=imm[11:5], [24:20]=rs2, [19:15]=rs1, [14:12]=funct3, [11:7]=imm[4:0], [6:0]=opcode
        function encode_S (
            imm    : std_logic_vector(11 downto 0);
            rs2    : std_logic_vector(4  downto 0);
            rs1    : std_logic_vector(4  downto 0);
            funct3 : std_logic_vector(2  downto 0);
            opcode : std_logic_vector(6  downto 0)
        ) return std_logic_vector is
        begin
            return imm(11 downto 5) & rs2 & rs1 & funct3 & imm(4 downto 0) & opcode;
        end function;

        -- B-type: [31]=imm[12], [30:25]=imm[10:5], [24:20]=rs2, [19:15]=rs1, [14:12]=funct3, [11:8]=imm[4:1], [7]=imm[11], [6:0]=opcode
        -- imm is a 13-bit value (imm[0] is always 0).
        function encode_B (
            imm    : std_logic_vector(12 downto 0);
            rs2    : std_logic_vector(4  downto 0);
            rs1    : std_logic_vector(4  downto 0);
            funct3 : std_logic_vector(2  downto 0);
            opcode : std_logic_vector(6  downto 0)
        ) return std_logic_vector is
            
        begin
            return imm(12)
                 & imm(10 downto 5)
                 & rs2 & rs1 & funct3
                 & imm(4 downto 1)
                 & imm(11)
                 & opcode;
        end function;

            
        -- U-type: [31:12]=imm[31:12], [11:7]=rd, [6:0]=opcode
        function encode_U (
            imm    : std_logic_vector(19 downto 0);
            rd     : std_logic_vector(4  downto 0);
            opcode : std_logic_vector(6  downto 0)
        ) return std_logic_vector is
        begin
            return imm & rd & opcode;
        end function;

        -- J-type: [31]=imm[20], [30:21]=imm[10:1], [20]=imm[11],[19:12]=imm[19:12], [11:7]=rd, [6:0]=opcode
        -- imm is a 21-bit value (imm[0] is always 0).
        function encode_J (
            imm    : std_logic_vector(20 downto 0);
            rd     : std_logic_vector(4  downto 0);
            opcode : std_logic_vector(6  downto 0)
        ) return std_logic_vector is
        begin
            return imm(20)
                 & imm(10 downto 1)
                 & imm(11)
                 & imm(19 downto 12)
                 & rd & opcode;
        end function;

            
        -- R-type: [31:25]=funct7, [24:20]=rs2, [19:15]=rs1,[14:12]=funct3, [11:7]=rd, [6:0]=opcode
        function encode_R (
            funct7 : std_logic_vector(6 downto 0);
            rs2    : std_logic_vector(4 downto 0);
            rs1    : std_logic_vector(4 downto 0);
            funct3 : std_logic_vector(2 downto 0);
            rd     : std_logic_vector(4 downto 0);
            opcode : std_logic_vector(6 downto 0)
        ) return std_logic_vector is
        begin
            return funct7 & rs2 & rs1 & funct3 & rd & opcode;
        end function;

        -- Opcode constants
        constant OP_I_ALU  : std_logic_vector(6 downto 0) := "0010011";
        constant OP_LOAD   : std_logic_vector(6 downto 0) := "0000011";
        constant OP_STORE  : std_logic_vector(6 downto 0) := "0100011";
        constant OP_BRANCH : std_logic_vector(6 downto 0) := "1100011";
        constant OP_JAL    : std_logic_vector(6 downto 0) := "1101111";
        constant OP_JALR   : std_logic_vector(6 downto 0) := "1100111";
        constant OP_LUI    : std_logic_vector(6 downto 0) := "0110111";
        constant OP_AUIPC  : std_logic_vector(6 downto 0) := "0010111";
        constant OP_R      : std_logic_vector(6 downto 0) := "0110011";

    begin

        report " imm_gen testbench starting" severity note;

        -- I-TYPE ALU (opcode = 0010011)


        -- addi x1, x2, -1
        -- imm = 0xFFF (all ones = -1 in 12-bit two's complement)
        -- expected: 0xFFFFFFFF
        check_imm(
            "I-type: addi x1,x2,-1 (negative imm)",
            encode_I(
                imm    => "111111111111",-- -1
                rs1    => "00010",-- x2
                funct3 => "000",
                rd     => "00001",-- x1
                opcode => OP_I_ALU
            ),
            expected => x"FFFFFFFF"
        );


        -- addi x0, x0, 0  (the NOP)
        -- imm = 0x000
        -- expected: 0x00000000
        check_imm(
            "I-type: addi x0,x0,0 (NOP / zero imm)",
            encode_I(
                imm    => "000000000000",
                rs1    => "00000",
                funct3 => "000",
                rd     => "00000",
                opcode => OP_I_ALU
            ),
            expected => x"00000000"
        );

        -- slli x3, x3, 4

        -- ** only the low 5 bits [4:0] are the shift amount, the generator output is 0x00000004.
        check_imm(
            "I-type: slli x3,x3,4 (shift amount in low bits)",
            encode_I(
                imm    => "000000000100",-- shamt=4, funct7=0x00
                rs1    => "00011",
                funct3 => "001",-- slli
                rd     => "00011",
                opcode => OP_I_ALU
            ),
            expected => x"00000004"
        );

        -- sltiu x4, x5, 2047
        -- imm = 0x7FF = 2047
        -- expected: 0x000007FF
        check_imm(
            "I-type: sltiu x4,x5,2047 (max positive 12-bit)",
            encode_I(
                imm    => "011111111111",-- 2047
                rs1    => "00101",
                funct3 => "011",-- sltiu
                rd     => "00100",
                opcode => OP_I_ALU
            ),
            expected => x"000007FF"
        );

        -- I-TYPE LOAD (opcode = 0000011)

        -- lw x6, 100(x7)
        -- imm = 100 = 0x064
        -- expected: 0x00000064
        check_imm(
            "I-type LOAD: lw x6,100(x7) (positive offset)",
            encode_I(
                imm    => "000001100100",-- 100
                rs1    => "00111", -- x7
                funct3 => "010", -- lw
                rd     => "00110",  -- x6
                opcode => OP_LOAD
            ),
            expected => x"00000064"
        );

        -- lb x8, -4(x9)
        -- imm = -4 = 0xFFC
        -- expected: 0xFFFFFFFC
        check_imm(
            "I-type LOAD: lb x8,-4(x9) (negative offset)",
            encode_I(
                imm    => "111111111100",-- -4
                rs1    => "01001", -- x9
                funct3 => "000",-- lb
                rd     => "01000",-- x8
                opcode => OP_LOAD
            ),
            expected => x"FFFFFFFC"
        );

        -- lbu x10, 8(x11)
        -- immediate is still sign-extended
        -- imm = 8 = 0x008
        -- expected: 0x00000008
        check_imm(
            "I-type LOAD: lbu x10,8(x11) (zero-ext data, sign-ext imm)",
            encode_I(
                imm    => "000000001000", -- 8
                rs1    => "01011",-- x11
                funct3 => "100",-- lbu
                rd     => "01010",-- x10
                opcode => OP_LOAD
            ),
            expected => x"00000008"
        );

        -- I-TYPE JALR (opcode = 1100111)

        -- jalr x0, x1, -8
        -- imm = -8 = 0xFF8
        -- expected: 0xFFFFFFF8
        check_imm(
            "I-type JALR: jalr x0,x1,-8 (negative)",
            encode_I(
                imm    => "111111111000",-- -8
                rs1    => "00001",-- x1 (ra)
                funct3 => "000",
                rd     => "00000",-- x0
                opcode => OP_JALR
            ),
            expected => x"FFFFFFF8"
        );

        -- S-TYPE (opcode = 0100011)

        -- sw x2, 12(x3)
        -- imm = 12 = 0x00C
        -- expected: 0x0000000C
        check_imm(
            "S-type: sw x2,12(x3) (positive, split bits)",
            encode_S(
                imm    => "000000001100",-- 12
                rs2    => "00010", -- x2
                rs1    => "00011", -- x3
                funct3 => "010",-- sw
                opcode => OP_STORE
            ),
            expected => x"0000000C"
        );

        -- sb x4, -1(x5)
        -- imm = -1 = 0xFFF
        -- expected: 0xFFFFFFFF
        check_imm(
            "S-type: sb x4,-1(x5) (negative, split bits)",
            encode_S(
                imm    => "111111111111",-- -1
                rs2    => "00100", -- x4
                rs1    => "00101",-- x5
                funct3 => "000",-- sb
                opcode => OP_STORE
            ),
            expected => x"FFFFFFFF"
        );

        -- sw x1, -2048(x2)
        -- imm = -2048 = 0x800
        -- expected: 0xFFFFF800
        check_imm(
            "S-type: sw x1,-2048(x2) (min negative 12-bit)",
            encode_S(
                imm    => "100000000000",   -- -2048
                rs2    => "00001",
                rs1    => "00010",
                funct3 => "010",
                opcode => OP_STORE
            ),
            expected => x"FFFFF800"
        );

        -- B-TYPE (opcode = 1100011)

        -- beq x1, x2, +8
        -- Branch offset = +8 bytes
        -- expected: 0x00000008
        check_imm(
            "B-type: beq x1,x2,+8 (forward branch)",
            encode_B(
                imm    => "0000000001000",-- +8, imm[12:0]
                rs2    => "00010",
                rs1    => "00001",
                funct3 => "000", -- beq
                opcode => OP_BRANCH
            ),
            expected => x"00000008"
        );

        -- bne x3, x4, -16
        -- offset = -16 = 0xFFFF0 in 32 bits.
        -- 13-bit two's complement of -16: 1_111111_10000 -> "1111111110000"
        -- expected: 0xFFFFFFF0
        check_imm(
            "B-type: bne x3,x4,-16 (backward branch, negative)",
            encode_B(
                imm    => "1111111110000",-- -16 in 13-bit signed
                rs2    => "00100",
                rs1    => "00011",
                funct3 => "001",-- bne
                opcode => OP_BRANCH
            ),
            expected => x"FFFFFFF0"
        );

        -- blt x5, x6, +4096  (large positive, exercises imm[12])
        -- 13-bit: 0b1_000000_00000_0 = 4096 -> "1000000000000"
        -- expected: 0x00001000
        check_imm(
            "B-type: blt x5,x6,+4096 (large positive, imm[12]=1 but positive)",
            encode_B(
                imm    => "0001000000000",-- +4096 in 13-bit  (sign bit 0)
                rs2    => "00110",
                rs1    => "00101",
                funct3 => "100",-- blt
                opcode => OP_BRANCH
            ),
            expected => x"00001000"
        );

        -- U-TYPE LUI (opcode = 0110111)

        -- lui x5, 0xABCDE
        -- upper 20 bits = 0xABCDE
        -- expected: 0xABCDE000
        check_imm(
            "U-type LUI: lui x5,0xABCDE (upper 20-bit pattern)",
            encode_U(
                imm    => "10101011110011011110",-- 0xABCDE
                rd     => "00101",
                opcode => OP_LUI
            ),
            expected => x"ABCDE000"
        );

        -- lui x1, 1
        -- upper 20 bits = 0x00001
        -- expected: 0x00001000
        check_imm(
            "U-type LUI: lui x1,1 (minimal upper)",
            encode_U(
                imm    => "00000000000000000001",-- 1
                rd     => "00001",
                opcode => OP_LUI
            ),
            expected => x"00001000"
        );

        -- U-TYPE AUIPC (opcode = 0010111)

        -- auipc x6, 1
        -- upper 20 bits = 0x00001
        -- expected: 0x00001000
        check_imm(
            "U-type AUIPC: auipc x6,1 (minimal upper)",
            encode_U(
                imm    => "00000000000000000001",
                rd     => "00110",
                opcode => OP_AUIPC
            ),
            expected => x"00001000"
        );

        -- auipc x7, 0xFFFFF
        -- expected: 0xFFFFF000
        check_imm(
            "U-type AUIPC: auipc x7,0xFFFFF (all-ones upper)",
            encode_U(
                imm    => "11111111111111111111",
                rd     => "00111",
                opcode => OP_AUIPC
            ),
            expected => x"FFFFF000"
        );

        -- J-TYPE JAL (opcode = 1101111)


        -- jal x1, +4
        -- 21-bit offset = 4: "000000000000000000100"
        -- expected: 0x00000004
        check_imm(
            "J-type JAL: jal x1,+4 (minimal forward jump)",
            encode_J(
                imm    => "000000000000000000100",-- +4
                rd     => "00001",
                opcode => OP_JAL
            ),
            expected => x"00000004"
        );

        -- jal x0, -4
        -- -4 in 21-bit two's complement:
        -- (sign bit 1, imm[19:12]=11111111, imm[11]=1, imm[10:1]=1111111110)
        -- expected: 0xFFFFFFFC
        check_imm(
            "J-type JAL: jal x0,-4 (backward jump, negative)",
            encode_J(
                imm    => "111111111111111111100",-- -4 in 21-bit signed
                rd     => "00000",
                opcode => OP_JAL
            ),
            expected => x"FFFFFFFC"
        );

        -- jal x1, +1048572  (largest positive JAL offset that fits,2^20 - 4 = 1048572)
        -- 21-bit: "0_11111111111_1_11111100" -> imm = 0x000FFFFC
        -- expected: 0x000FFFFC
        check_imm(
            "J-type JAL: jal x1,+1048572 (near max positive offset)",
            encode_J(
                imm    => "001111111111111111100",-- 1048572
                rd     => "00001",
                opcode => OP_JAL
            ),
            expected => x"000FFFFC"
        );

        -- R-TYPE (opcode = 0110011), no immediate

        -- add x1, x2, x3 -> expected: 0x00000000
        check_imm(
            "R-type: add x1,x2,x3 (no immediate -> zero)",
            encode_R(
                funct7 => "0000000",
                rs2    => "00011",
                rs1    => "00010",
                funct3 => "000",
                rd     => "00001",
                opcode => OP_R
            ),
            expected => x"00000000"
        );

        -- sub x4, x5, x6 -> expected: 0x00000000
        check_imm(
            "R-type: sub x4,x5,x6 (no immediate -> zero)",
            encode_R(
                funct7 => "0100000",
                rs2    => "00110",
                rs1    => "00101",
                funct3 => "000",
                rd     => "00100",
                opcode => OP_R
            ),
            expected => x"00000000"
        );


        if all_pass then
            report " ALL TESTS PASSED" severity note;
        else
            report " ONE OR MORE TESTS FAILED" severity error;
        end if;

        wait; -- stop simulation
    end process;

end architecture behavioral;
