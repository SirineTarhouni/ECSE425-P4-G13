library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_tb is
end entity alu_tb;

architecture behavioral of alu_tb is

    signal op_a   : std_logic_vector(31 downto 0) := (others => '0');
    signal op_b   : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_op : std_logic_vector(3 downto 0)  := (others => '0');
    signal result : std_logic_vector(31 downto 0);

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


    procedure check(
        test_name : in string;
        got       : in std_logic_vector(31 downto 0);
        expected  : in std_logic_vector(31 downto 0)
    ) is
    begin
        if got = expected then
            report "PASS: " & test_name severity note;
        else
            report "FAIL: " & test_name &
                   "  got="      & integer'image(to_integer(signed(got))) &
                   "  expected=" & integer'image(to_integer(signed(expected)))
                   severity error;
        end if;
    end procedure;

begin

    uut: entity work.alu
        port map (
            op_a   => op_a,
            op_b   => op_b,
            alu_op => alu_op,
            result => result
        );

    process
    begin

        -- ADD 
        -- 5 + 3 = 8
        op_a   <= std_logic_vector(to_signed(5, 32));
        op_b   <= std_logic_vector(to_signed(3, 32));
        alu_op <= ALU_ADD;
        wait for 10 ns;
        check("ADD 5+3", result, std_logic_vector(to_signed(8, 32)));

        -- -5 + -3 = -8  (signed overflow check)
        op_a   <= std_logic_vector(to_signed(-5, 32));
        op_b   <= std_logic_vector(to_signed(-3, 32));
        alu_op <= ALU_ADD;
        wait for 10 ns;
        check("ADD -5+(-3)", result, std_logic_vector(to_signed(-8, 32)));

        -- SUB 
        -- 10 - 4 = 6
        op_a   <= std_logic_vector(to_signed(10, 32));
        op_b   <= std_logic_vector(to_signed(4, 32));
        alu_op <= ALU_SUB;
        wait for 10 ns;
        check("SUB 10-4", result, std_logic_vector(to_signed(6, 32)));

        -- 3 - 7 = -4
        op_a   <= std_logic_vector(to_signed(3, 32));
        op_b   <= std_logic_vector(to_signed(7, 32));
        alu_op <= ALU_SUB;
        wait for 10 ns;
        check("SUB 3-7", result, std_logic_vector(to_signed(-4, 32)));

        -- AND 
        -- 0xF0 & 0xFF = 0xF0
        op_a   <= x"000000F0";
        op_b   <= x"000000FF";
        alu_op <= ALU_AND;
        wait for 10 ns;
        check("AND 0xF0 & 0xFF", result, x"000000F0");

        -- OR 
        -- 0xF0 | 0x0F = 0xFF
        op_a   <= x"000000F0";
        op_b   <= x"0000000F";
        alu_op <= ALU_OR;
        wait for 10 ns;
        check("OR 0xF0 | 0x0F", result, x"000000FF");

        -- XOR
        -- 0xFF ^ 0x0F = 0xF0
        op_a   <= x"000000FF";
        op_b   <= x"0000000F";
        alu_op <= ALU_XOR;
        wait for 10 ns;
        check("XOR 0xFF ^ 0x0F", result, x"000000F0");

        -- SLL 
        -- 1 << 4 = 16
        op_a   <= std_logic_vector(to_unsigned(1, 32));
        op_b   <= std_logic_vector(to_unsigned(4, 32)); -- shamt = low 5 bits = 4
        alu_op <= ALU_SLL;
        wait for 10 ns;
        check("SLL 1<<4", result, std_logic_vector(to_unsigned(16, 32)));

        -- SRL
        -- 16 >> 2 = 4  (logical, fills with 0)
        op_a   <= std_logic_vector(to_unsigned(16, 32));
        op_b   <= std_logic_vector(to_unsigned(2, 32));
        alu_op <= ALU_SRL;
        wait for 10 ns;
        check("SRL 16>>2", result, std_logic_vector(to_unsigned(4, 32)));

        -- 0x80000000 >> 1 logical = 0x40000000  (MSB does NOT replicate)
        op_a   <= x"80000000";
        op_b   <= std_logic_vector(to_unsigned(1, 32));
        alu_op <= ALU_SRL;
        wait for 10 ns;
        check("SRL 0x80000000>>1", result, x"40000000");

        -- SRA
        -- 0x80000000 >> 1 arithmetic = 0xC0000000  (MSB DOES replicate)
        op_a   <= x"80000000";
        op_b   <= std_logic_vector(to_unsigned(1, 32));
        alu_op <= ALU_SRA;
        wait for 10 ns;
        check("SRA 0x80000000>>1", result, x"C0000000");

        -- -8 >> 2 = -2  (arithmetic preserves sign)
        op_a   <= std_logic_vector(to_signed(-8, 32));
        op_b   <= std_logic_vector(to_unsigned(2, 32));
        alu_op <= ALU_SRA;
        wait for 10 ns;
        check("SRA -8>>2", result, std_logic_vector(to_signed(-2, 32)));

        -- SLT
        -- 3 < 5 = 1
        op_a   <= std_logic_vector(to_signed(3, 32));
        op_b   <= std_logic_vector(to_signed(5, 32));
        alu_op <= ALU_SLT;
        wait for 10 ns;
        check("SLT 3<5 (expect 1)", result, x"00000001");

        -- 5 < 3 = 0
        op_a   <= std_logic_vector(to_signed(5, 32));
        op_b   <= std_logic_vector(to_signed(3, 32));
        alu_op <= ALU_SLT;
        wait for 10 ns;
        check("SLT 5<3 (expect 0)", result, x"00000000");

        -- -1 < 1 = 1  (signed: -1 is less than 1)
        op_a   <= std_logic_vector(to_signed(-1, 32));
        op_b   <= std_logic_vector(to_signed(1, 32));
        alu_op <= ALU_SLT;
        wait for 10 ns;
        check("SLT -1<1 signed (expect 1)", result, x"00000001");

        -- SLTU
        -- 0xFFFFFFFF < 0x1 unsigned = 0  (0xFFFFFFFF is a huge positive number)
        -- This is the OPPOSITE of signed comparison where -1 < 1
        op_a   <= x"FFFFFFFF";
        op_b   <= std_logic_vector(to_signed(1, 32));
        alu_op <= ALU_SLTU;
        wait for 10 ns;
        check("SLTU 0xFFFFFFFF<1 unsigned (expect 0)", result, x"00000000");

        -- 1 < 0xFFFFFFFF unsigned = 1
        op_a   <= std_logic_vector(to_signed(1, 32));
        op_b   <= x"FFFFFFFF";
        alu_op <= ALU_SLTU;
        wait for 10 ns;
        check("SLTU 1<0xFFFFFFFF unsigned (expect 1)", result, x"00000001");

        -- LUI
        -- lui x1, 1 -> immediate is already shifted to 0x00001000
        op_a   <= x"00000000"; -- irrelevant for LUI
        op_b   <= x"00001000";
        alu_op <= ALU_LUI;
        wait for 10 ns;
        check("LUI passthrough 0x00001000", result, x"00001000");

        -- MUL
        -- 5 * 6 = 30
        op_a   <= std_logic_vector(to_signed(5, 32));
        op_b   <= std_logic_vector(to_signed(6, 32));
        alu_op <= ALU_MUL;
        wait for 10 ns;
        check("MUL 5*6", result, std_logic_vector(to_signed(30, 32)));

        -- -3 * 4 = -12
        op_a   <= std_logic_vector(to_signed(-3, 32));
        op_b   <= std_logic_vector(to_signed(4, 32));
        alu_op <= ALU_MUL;
        wait for 10 ns;
        check("MUL -3*4", result, std_logic_vector(to_signed(-12, 32)));

        -- 0 * anything = 0
        op_a   <= std_logic_vector(to_signed(0, 32));
        op_b   <= std_logic_vector(to_signed(99, 32));
        alu_op <= ALU_MUL;
        wait for 10 ns;
        check("MUL 0*99", result, std_logic_vector(to_signed(0, 32)));

        -- Edge cases 
        -- ADD with 0
        op_a   <= std_logic_vector(to_signed(42, 32));
        op_b   <= std_logic_vector(to_signed(0, 32));
        alu_op <= ALU_ADD;
        wait for 10 ns;
        check("ADD 42+0", result, std_logic_vector(to_signed(42, 32)));

        -- SLL shift by 0 = no change
        op_a   <= std_logic_vector(to_unsigned(7, 32));
        op_b   <= std_logic_vector(to_unsigned(0, 32));
        alu_op <= ALU_SLL;
        wait for 10 ns;
        check("SLL shift by 0", result, std_logic_vector(to_unsigned(7, 32)));

        -- SLT equal values = 0
        op_a   <= std_logic_vector(to_signed(5, 32));
        op_b   <= std_logic_vector(to_signed(5, 32));
        alu_op <= ALU_SLT;
        wait for 10 ns;
        check("SLT equal (expect 0)", result, x"00000000");

        report "==============================" severity note;
        report "All tests done." severity note;
        report "==============================" severity note;

        wait; -- stop simulation
    end process;

end architecture behavioral;

