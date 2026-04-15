library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



library std;
use std.textio.all;

entity mem_tb is
end entity mem_tb;

architecture behavioral of mem_tb is

    constant CLK_PERIOD : time := 1 ns;
    signal clk : std_logic := '0';
--

    signal imem_address         : std_logic_vector(31 downto 0) := (others => '0');
    signal imem_instruction_out : std_logic_vector(31 downto 0);

    signal dmem_address    : std_logic_vector(31 downto 0) := (others => '0');
    signal dmem_write_data : std_logic_vector(31 downto 0) := (others => '0');
    signal dmem_mem_read   : std_logic := '0';
    signal dmem_mem_write  : std_logic := '0';
    signal dmem_mem_size   : std_logic_vector(1 downto 0) := "10";
    signal dmem_mem_signed : std_logic := '1';
    signal dmem_read_data  : std_logic_vector(31 downto 0);


    shared variable all_pass : boolean := true;
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
        
    function to_hex_string(slv : std_logic_vector) return string is
        variable result : string(1 to slv'length/4);
        variable temp   : std_logic_vector(3 downto 0);
    begin
        for i in 0 to (slv'length/4 - 1) loop
            temp := slv(slv'length-1 - i*4 downto slv'length-4 - i*4);
            case temp is
                when "0000" => result(i+1) := '0';
                when "0001" => result(i+1) := '1';
                when "0010" => result(i+1) := '2';
                when "0011" => result(i+1) := '3';
                when "0100" => result(i+1) := '4';
                when "0101" => result(i+1) := '5';
                when "0110" => result(i+1) := '6';
                when "0111" => result(i+1) := '7';
                when "1000" => result(i+1) := '8';
                when "1001" => result(i+1) := '9';
                when "1010" => result(i+1) := 'A';
                when "1011" => result(i+1) := 'B';
                when "1100" => result(i+1) := 'C';
                when "1101" => result(i+1) := 'D';
                when "1110" => result(i+1) := 'E';
                when others => result(i+1) := 'F';
            end case;
        end loop;
        return result;
    end function;

begin

    clk <= not clk after CLK_PERIOD / 2;
---
    imem : instruction_mem
        port map (
            clk             => clk,
            address         => imem_address,
            instruction_out => imem_instruction_out
        );

    dmem : data_mem
        port map (
            clk        => clk,
            address    => dmem_address,
            write_data => dmem_write_data,
            mem_read   => dmem_mem_read,
            mem_write  => dmem_mem_write,
            mem_size   => dmem_mem_size,
            mem_signed => dmem_mem_signed,
            read_data  => dmem_read_data
        );

    stimulus : process

        -- ----------------------------------------------------
        -- Write "program.txt" so instruction_mem can load it.
        --
        -- We use four hand-crafted 32-bit instruction words
        -- that are easy to verify:
        --   Word 0: addi x1, x0, 1   = 0x00100093
        --   Word 1: addi x2, x0, 2   = 0x00200113
        --   Word 2: add  x3, x1, x2  = 0x002081B3
        --   Word 3: sw   x3, 0(x0)   = 0x00302023
        --
        -- Encoded as 32-character binary strings (MSB first).
        -- ----------------------------------------------------
        procedure write_program_txt is
            file     f    : text;
            variable fline : line;
        begin
            file_open(f, "program.txt", write_mode);

            -- Word 0: 0x00100093
            -- 0000 0000 0001 0000 0000 0000 1001 0011
            write(fline, string'("00000000000100000000000010010011"));
            writeline(f, fline);

            -- Word 1: 0x00200113
            -- 0000 0000 0010 0000 0000 0001 0001 0011
            write(fline, string'("00000000001000000000000100010011"));
            writeline(f, fline);

            -- Word 2: 0x002081B3
            -- 0000 0000 0010 0000 1000 0001 1011 0011
            write(fline, string'("00000000001000001000000110110011"));
            writeline(f, fline);

            -- Word 3: 0x00302023
            -- 0000 0000 0011 0000 0010 0000 0010 0011
            write(fline, string'("00000000001100000010000000100011"));
            writeline(f, fline);

            file_close(f);
        end procedure;

        -- ----------------------------------------------------
        -- Generic check procedure
        -- ----------------------------------------------------
        procedure check (
            test_name : in string;
            got       : in std_logic_vector(31 downto 0);
            expected  : in std_logic_vector(31 downto 0)
        ) is begin
            if got = expected then
                report "[PASS] " & test_name severity note;
            else
                report "[FAIL] " & test_name
                     & "  expected=0x" & to_hex_string(expected)
                     & "  got=0x"      & to_hex_string(got)
                     severity error;
                all_pass := false;
            end if;
        end procedure;

        -- Convenience: wait for one full clock cycle and then
        -- sample on the next delta (output is stable by then).
        procedure tick is begin
            wait until rising_edge(clk);
            wait for 1 ps;   -- tiny delta so output has settled
        end procedure;

    begin

        -- Write program.txt before elaboration reads it —
        -- call early so the file exists when imem loads.
        write_program_txt;

        -- Let the clock stabilise for a couple of cycles.
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        report "======================================" severity note;
        report " instruction_mem tests" severity note;
        report "======================================" severity note;

        -- ====================================================
        -- INSTRUCTION MEMORY TESTS
        -- ====================================================

        -- Present address 0, wait one cycle for the synchronous
        -- read to complete, then check the result.

        -- Word 0: addi x1, x0, 1  = 0x00100093
        imem_address <= x"00000000";
        tick;
        check("imem word 0 (addi x1,x0,1)", imem_instruction_out, x"00100093");

        -- Word 1: addi x2, x0, 2  = 0x00200113
        imem_address <= x"00000004";
        tick;
        check("imem word 1 (addi x2,x0,2)", imem_instruction_out, x"00200113");

        -- Word 2: add x3, x1, x2  = 0x002081B3
        imem_address <= x"00000008";
        tick;
        check("imem word 2 (add x3,x1,x2)", imem_instruction_out, x"002081B3");

        -- Word 3: sw x3, 0(x0)   = 0x00302023
        imem_address <= x"0000000C";
        tick;
        check("imem word 3 (sw x3,0(x0))", imem_instruction_out, x"00302023");

        -- Words beyond what was loaded should be zero.
        imem_address <= x"00000010";
        tick;
        check("imem beyond program (should be 0)", imem_instruction_out, x"00000000");

        -- Out-of-range address (> 4095) should return 0 safely.
        imem_address <= x"FFFFFFF0";
        tick;
        check("imem out-of-range address (should be 0)", imem_instruction_out, x"00000000");

        -- Re-read word 0 to confirm memory is stable.
        imem_address <= x"00000000";
        tick;
        check("imem word 0 re-read (stability)", imem_instruction_out, x"00100093");

        report "======================================" severity note;
        report " data_mem tests" severity note;
        report "======================================" severity note;

        -- ====================================================
        -- DATA MEMORY TESTS
        -- ====================================================

        -- ---- Initialisation check --------------------------
        -- Read from address 0 without writing first; expect 0.
        dmem_address    <= x"00000000";
        dmem_mem_read   <= '1';
        dmem_mem_write  <= '0';
        dmem_mem_size   <= "10";
        dmem_mem_signed <= '1';
        tick;
        check("dmem init: address 0 reads as 0", dmem_read_data, x"00000000");

        dmem_mem_read <= '0';

        -- ---- Word store / load (sw / lw) -------------------
        -- Write 0xDEADBEEF to address 0x100, read it back.
        dmem_address    <= x"00000100";
        dmem_write_data <= x"DEADBEEF";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "10";   -- word
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "10";
        dmem_mem_signed <= '1';
        tick;
        check("dmem sw/lw: 0xDEADBEEF @ 0x100", dmem_read_data, x"DEADBEEF");
        dmem_mem_read <= '0';

        -- ---- Halfword signed store / load (sh / lh) --------
        -- Write 0x????8ABC to address 0x104 (sh writes low 16 bits).
        -- 0x8ABC sign-extended = 0xFFFF8ABC.
        dmem_address    <= x"00000104";
        dmem_write_data <= x"00008ABC";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "01";   -- halfword
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "01";
        dmem_mem_signed <= '1';    -- lh: sign-extend
        tick;
        check("dmem sh/lh: 0x8ABC sign-extended", dmem_read_data, x"FFFF8ABC");
        dmem_mem_read <= '0';

        -- ---- Halfword unsigned load (lhu) ------------------
        -- Same address, same stored value, zero-extend this time.
        dmem_address    <= x"00000104";
        dmem_mem_read   <= '1';
        dmem_mem_size   <= "01";
        dmem_mem_signed <= '0';    -- lhu: zero-extend
        tick;
        check("dmem lhu: 0x8ABC zero-extended", dmem_read_data, x"00008ABC");
        dmem_mem_read <= '0';

        -- ---- Byte signed store / load (sb / lb) ------------
        -- Write 0xAB to address 0x108.
        -- 0xAB sign-extended = 0xFFFFFFAB.
        dmem_address    <= x"00000108";
        dmem_write_data <= x"000000AB";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "00";   -- byte
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "00";
        dmem_mem_signed <= '1';    -- lb: sign-extend
        tick;
        check("dmem sb/lb: 0xAB sign-extended", dmem_read_data, x"FFFFFFAB");
        dmem_mem_read <= '0';

        -- ---- Byte unsigned load (lbu) ----------------------
        dmem_address    <= x"00000108";
        dmem_mem_read   <= '1';
        dmem_mem_size   <= "00";
        dmem_mem_signed <= '0';    -- lbu: zero-extend
        tick;
        check("dmem lbu: 0xAB zero-extended", dmem_read_data, x"000000AB");
        dmem_mem_read <= '0';

        -- ---- Positive byte (no sign extension difference) --
        -- Write 0x7F to address 0x10C.
        -- 0x7F sign-extended = 0x0000007F (same as zero-extend).
        dmem_address    <= x"0000010C";
        dmem_write_data <= x"0000007F";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "00";
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "00";
        dmem_mem_signed <= '1';
        tick;
        check("dmem lb: 0x7F (positive) sign-extended", dmem_read_data, x"0000007F");
        dmem_mem_read <= '0';

        -- ---- Little-endian byte order ----------------------
        -- Store 0x12345678 as a word at 0x200 and then load
        -- each byte individually to confirm little-endian layout:
        --   byte 0 (addr 0x200) = 0x78
        --   byte 1 (addr 0x201) = 0x56
        --   byte 2 (addr 0x202) = 0x34
        --   byte 3 (addr 0x203) = 0x12
        dmem_address    <= x"00000200";
        dmem_write_data <= x"12345678";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "10";  -- sw
        tick;
        dmem_mem_write  <= '0';

        -- byte 0
        dmem_address    <= x"00000200";
        dmem_mem_read   <= '1';
        dmem_mem_size   <= "00";
        dmem_mem_signed <= '0';
        tick;
        check("dmem little-endian byte 0 = 0x78", dmem_read_data, x"00000078");

        -- byte 1
        dmem_address    <= x"00000201";
        tick;
        check("dmem little-endian byte 1 = 0x56", dmem_read_data, x"00000056");

        -- byte 2
        dmem_address    <= x"00000202";
        tick;
        check("dmem little-endian byte 2 = 0x34", dmem_read_data, x"00000034");

        -- byte 3
        dmem_address    <= x"00000203";
        tick;
        check("dmem little-endian byte 3 = 0x12", dmem_read_data, x"00000012");

        dmem_mem_read <= '0';

        -- ---- Boundary: last word address (32764 = 0x7FFC) --
        dmem_address    <= x"00007FFC";
        dmem_write_data <= x"CAFEBABE";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "10";
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "10";
        dmem_mem_signed <= '1';
        tick;
        check("dmem boundary: last word (0x7FFC)", dmem_read_data, x"CAFEBABE");
        dmem_mem_read <= '0';

        -- ---- Overwrite: second store replaces first --------
        dmem_address    <= x"00000300";
        dmem_write_data <= x"AAAAAAAA";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "10";
        tick;

        dmem_write_data <= x"55555555";
        tick;
        dmem_mem_write  <= '0';

        dmem_mem_read   <= '1';
        dmem_mem_size   <= "10";
        dmem_mem_signed <= '1';
        tick;
        check("dmem overwrite: 2nd store wins", dmem_read_data, x"55555555");
        dmem_mem_read <= '0';

        -- ---- Write then immediately read different location --
        -- Confirm a write to 0x400 doesn't corrupt 0x100.
        dmem_address    <= x"00000400";
        dmem_write_data <= x"FEEDFACE";
        dmem_mem_write  <= '1';
        dmem_mem_size   <= "10";
        tick;
        dmem_mem_write  <= '0';

        dmem_address    <= x"00000100";
        dmem_mem_read   <= '1';
        dmem_mem_size   <= "10";
        dmem_mem_signed <= '1';
        tick;
        check("dmem isolation: 0x100 still 0xDEADBEEF", dmem_read_data, x"DEADBEEF");
        dmem_mem_read <= '0';

        -- ====================================================
        -- Summary
        -- ====================================================
        report "======================================" severity note;
        if all_pass then
            report " ALL TESTS PASSED" severity note;
        else
            report " ONE OR MORE TESTS FAILED" severity error;
        end if;
        report "======================================" severity note;

        wait;
    end process stimulus;

end architecture behavioral;
