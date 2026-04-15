library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file_tb is
end entity register_file_tb;

architecture behavioral of register_file_tb is
  
    signal clk      : std_logic := '0';

    signal rs1_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal rs2_addr : std_logic_vector(4 downto 0) := (others => '0');
    signal rs1_data : std_logic_vector(31 downto 0);
    signal rs2_data : std_logic_vector(31 downto 0);

    signal rd_addr   : std_logic_vector(4 downto 0)  := (others => '0');
    signal rd_data   : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_write : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;

    --helper function that gives u passing or failing report
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
  
    clk <= not clk after CLK_PERIOD / 2;
          
    uut: entity work.register_file
        port map (
            clk       => clk,
            rs1_addr  => rs1_addr,
            rs2_addr  => rs2_addr,
            rs1_data  => rs1_data,
            rs2_data  => rs2_data,
            rd_addr   => rd_addr,
            rd_data   => rd_data,
            reg_write => reg_write
        );

    process
    begin

        -- POWER-ON STATE
        report "--- Power-on: all registers should be initialized at zero ---" severity note;

        rs1_addr <= "00000"; rs2_addr <= "00001";
        wait for 5 ns;
        check("x0 reads zero at startup", rs1_data, x"00000000");
        check("x1 reads zero at startup", rs2_data, x"00000000");

        rs1_addr <= "11111"; -- x31
        wait for 5 ns;
        check("x31 reads zero at startup", rs1_data, x"00000000");

        -- WRITE THEN READ BACK
        -- Write 0xDEADBEEF to x5, then read x5 back.
        report "--- Basic write then read back ---" severity note;

        rd_addr   <= "00101"; -- x5
        rd_data   <= x"DEADBEEF";
        reg_write <= '1';
        wait until rising_edge(clk); -- write commits here
        wait for 1 ns;

        reg_write <= '0';
        rs1_addr  <= "00101"; -- read x5
        wait for 5 ns;
        check("x5 read back after write", rs1_data, x"DEADBEEF");

        -- TWO SIMULTANEOUS READS RETURN INDEPENDENT VALUES
        -- Write distinct values to x7 and x8, then read both at the same time through rs1 and rs2.
        report "--- Two simultaneous reads ---" severity note;

        -- Write x7 = 0x00000007
        rd_addr   <= "00111"; rd_data <= x"00000007"; reg_write <= '1';
        wait until rising_edge(clk); wait for 1 ns;

        -- Write x8 = 0x00000008
        rd_addr   <= "01000"; rd_data <= x"00000008"; reg_write <= '1';
        wait until rising_edge(clk); wait for 1 ns;

        reg_write <= '0';
        rs1_addr  <= "00111"; -- x7
        rs2_addr  <= "01000"; -- x8
        wait for 5 ns;
        check("rs1 = x7 = 7",  rs1_data, x"00000007");
        check("rs2 = x8 = 8",  rs2_data, x"00000008");

        -- reg_write = '0' DOES NOT MODIFY THE REGISTER
        -- Try to write 0xBADC0DE to x5 with reg_write deasserted.
        -- x5 should still hold 0xDEADBEEF from test 2.
        report "--- reg_write=0 does not write ---" severity note;

        rd_addr   <= "00101"; -- x5
        rd_data   <= x"BADC0DE0";
        reg_write <= '0';            -- NOT asserting write enable
        wait until rising_edge(clk); wait for 1 ns;

        rs1_addr <= "00101";
        wait for 5 ns;
        check("x5 unchanged when reg_write=0", rs1_data, x"DEADBEEF");

        -- WRITING x0 IS SILENTLY IGNORED
        -- Try to write 0xFFFFFFFF to x0.  x0 must stay zero.
        -- This is the most important architectural invariant.
        report "--- Write to x0 is ignored ---" severity note;

        rd_addr   <= "00000"; -- x0
        rd_data   <= x"FFFFFFFF";
        reg_write <= '1';
        wait until rising_edge(clk); wait for 1 ns;

        reg_write <= '0';
        rs1_addr  <= "00000"; -- read back x0
        wait for 5 ns;
        check("x0 stays zero after write attempt", rs1_data, x"00000000");

        -- SWEEP: write a unique value to x1 through x31, then read every one back and verify.
        -- We write i to register xi (i = 1..31) so it is easy
        -- to spot if the wrong register was written.
        report "--- Sweep: write unique value to x1-x31 ---" severity note;

        for i in 1 to 31 loop
            rd_addr   <= std_logic_vector(to_unsigned(i, 5));
            rd_data   <= std_logic_vector(to_unsigned(i * 4, 32));
            reg_write <= '1';
            wait until rising_edge(clk); wait for 1 ns;
        end loop;

        reg_write <= '0';

        report "--- Sweep: read back x1-x31 ---" severity note;

        for i in 1 to 31 loop
            rs1_addr <= std_logic_vector(to_unsigned(i, 5));
            wait for 5 ns;
            check(
                "Sweep x" & integer'image(i),
                rs1_data,
                std_logic_vector(to_unsigned(i * 4, 32))
            );
        end loop;

        -- x0 must still be zero after the sweep
        rs1_addr <= "00000";
        wait for 5 ns;
        check("x0 still zero after sweep", rs1_data, x"00000000");

        -- OVERWRITE — write a new value to a register that already holds data and verify the old value is gone.
        report "--- Overwrite existing register ---" severity note;

        rd_addr   <= "00101"; -- x5 currently holds 0xDEADBEEF
        rd_data   <= x"CAFEBABE";
        reg_write <= '1';
        wait until rising_edge(clk); wait for 1 ns;

        reg_write <= '0';
        rs1_addr  <= "00101";
        wait for 5 ns;
        check("x5 overwritten to 0xCAFEBABE", rs1_data, x"CAFEBABE");

        report "==============================" severity note;
        report "All tests done." severity note;
        report "==============================" severity note;

        wait;
    end process;

end architecture behavioral;
