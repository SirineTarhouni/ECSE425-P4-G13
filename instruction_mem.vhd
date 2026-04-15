-- ============================================================
-- instruction_mem.vhd
-- ECSE 425 - Pipelined Processor
--
-- Read-only instruction memory for the RISC-V pipeline.
-- Holds up to 1024 32-bit instructions (4096 bytes).
--
-- The memory is loaded at simulation start from an ASCII text
-- file called "program.txt" in the working directory.  Each
-- line of that file contains exactly 32 '0'/'1' characters
-- representing one instruction word in big-endian binary
-- (MSB first), as produced by the provided RISC-V assembler.
--
-- ACCESS MODEL:
--   Read is synchronous: on the rising edge of clk the word
--   at mem[address / 4] is registered into instruction_out.
--   This introduces one cycle of read latency, matching the
--   IF stage behaviour assumed by the pipeline (the IF/ID
--   register latches the output one cycle later).
--
--   address is a byte address; the bottom two bits are
--   ignored (word-aligned access only).
--
-- The memory is 1-cycle latency (delay = 1 clock period).
-- Its size is fixed at 1024 words = 4096 bytes, which is
-- sufficient to hold "at most 1024 instructions" per spec.
--
-- INPUTS:
--   clk           : system clock
--   address       : 32-bit byte address (word-aligned)
--
-- OUTPUTS:
--   instruction_out : 32-bit instruction word at address
-- ============================================================

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

    -- --------------------------------------------------------
    -- Memory array: 1024 words of 32 bits each.
    -- Initialised to all-zeros (NOP = addi x0,x0,0 = 0x00000013
    -- is non-zero, but a zero word decodes as a harmless
    -- all-zero R-type instruction with no side effects).
    -- --------------------------------------------------------
    constant MEM_DEPTH : integer := 1024;

    type mem_array is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);

    -- --------------------------------------------------------
    -- impure function: reads program.txt at elaboration time
    -- and returns the populated memory array.
    -- impure is required because it accesses an external file.
    -- --------------------------------------------------------
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
