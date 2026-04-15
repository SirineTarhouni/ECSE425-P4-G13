-- INPUTS:
--   clk           : system clock
--   address       : 32-bit byte address (word-aligned)
--
-- OUTPUTS:
--   instruction_out : 32-bit instruction word at address
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity instruction_mem is
    port (
        clk             : in  std_logic;
        address         : in  std_logic_vector(31 downto 0);
        instruction_out : out std_logic_vector(31 downto 0)
    );
end entity instruction_mem;

architecture behavioral of instruction_mem is

    -- Memory array: 1024 words of 32 bits each.
    constant MEM_DEPTH : integer := 1024;
    type mem_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);

    -- impure function: reads program.txt at elaboration time and returns the populated memory array
    -- impure is required because it accesses an external file
    impure function load_program return mem_array is
        file     prog_file  : text;
        variable file_line  : line;
        variable mem        : mem_array := (others => (others => '0'));
        variable word       : std_logic_vector(31 downto 0);
        variable word_index : integer := 0;
        variable ok         : boolean;
    begin
        file_open(prog_file, "program.txt", read_mode);

        while not endfile(prog_file) and word_index < MEM_DEPTH loop
            readline(prog_file, file_line);

            -- Skip empty lines that may appear at end of file.
            if file_line'length = 32 then
                read(file_line, word, ok);
                if ok then
                    mem(word_index) := word;
                    word_index := word_index + 1;
                end if;
            end if;
        end loop;

        file_close(prog_file);
        return mem;
    end function;

    signal mem : mem_array := load_program;

begin

    read_port : process(address)
    variable word_addr : integer;
begin
    word_addr := to_integer(unsigned(address(11 downto 2)));
    if word_addr >= 0 and word_addr < MEM_DEPTH then
        instruction_out <= mem(word_addr);
    else
        instruction_out <= (others => '0');
    end if;
end process read_port;

end architecture behavioral;
