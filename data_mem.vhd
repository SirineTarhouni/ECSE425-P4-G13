-- ============================================================
-- data_mem.vhd
-- ECSE 425 - Pipelined Processor
--
-- Read/write data memory for the RISC-V pipeline.
-- Total size: 32768 bytes = 8192 32-bit words.
-- Initialised entirely to 0x00 at reset, per spec.
--
-- ACCESS MODEL:
--   Both reads and writes are synchronous (rising-edge).
--   This gives a 1-cycle latency matching the MEM stage.
--
--   address is a byte address.  The bottom bits are masked
--   appropriately for the access size:
--     byte     : any byte address (address as-is)
--     halfword : address must be 2-byte aligned (addr & ~1)
--     word     : address must be 4-byte aligned (addr & ~3)
--
-- READ (load):
--   When mem_read = '1', the appropriate byte(s) are read and
--   extended to 32 bits according to mem_size and mem_signed:
--     mem_size  "00" = byte (8 bits)
--               "01" = halfword (16 bits)
--               "10" = word (32 bits)
--     mem_signed '1' = sign-extend  (lb, lh, lw)
--                '0' = zero-extend  (lbu, lhu)
--
-- WRITE (store):
--   When mem_write = '1', the appropriate byte(s) of
--   write_data are stored at address, controlled by mem_size:
--     "00" = store lowest byte   of write_data  (sb)
--     "01" = store lowest 2 bytes of write_data (sh)
--     "10" = store all 4 bytes   of write_data  (sw)
--
-- INPUTS:
--   clk        : system clock
--   address    : 32-bit byte address
--   write_data : 32-bit value to write (stores)
--   mem_read   : '1' = perform a load this cycle
--   mem_write  : '1' = perform a store this cycle
--   mem_size   : "00"=byte, "01"=half, "10"=word
--   mem_signed : '1' = sign-extend on load
--
-- OUTPUTS:
--   read_data  : 32-bit loaded value (registered)
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_mem is
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
end entity data_mem;

architecture behavioral of data_mem is

    -- --------------------------------------------------------
    -- 32768-byte memory stored as individual bytes.
    -- Byte-addressable storage makes sub-word accesses clean.
    -- Initialised entirely to zero per spec.
    -- --------------------------------------------------------
    constant MEM_BYTES : integer := 32768;

    type byte_array is array (0 to MEM_BYTES - 1) of std_logic_vector(7 downto 0);

    signal mem : byte_array := (others => (others => '0'));

begin

    mem_access : process(clk)
        variable byte_addr : integer;
        variable b0, b1, b2, b3 : std_logic_vector(7 downto 0);
        variable sign_bit : std_logic;
    begin
        if rising_edge(clk) then

            -- Convert byte address, clamped to valid range.
            byte_addr := to_integer(unsigned(address)) mod MEM_BYTES;

            -- ------------------------------------------------
            -- WRITE (store) — takes priority if both asserted.
            -- Stores write only the bytes selected by mem_size.
            -- ------------------------------------------------
            if mem_write = '1' then
                case mem_size is

                    when "00" =>  -- sb: store lowest byte
                        mem(byte_addr) <= write_data(7 downto 0);

                    when "01" =>  -- sh: store lowest halfword (little-endian)
                        mem(byte_addr)     <= write_data(7  downto 0);
                        mem(byte_addr + 1) <= write_data(15 downto 8);

                    when others =>  -- sw: store full word (little-endian)
                        mem(byte_addr)     <= write_data(7  downto 0);
                        mem(byte_addr + 1) <= write_data(15 downto 8);
                        mem(byte_addr + 2) <= write_data(23 downto 16);
                        mem(byte_addr + 3) <= write_data(31 downto 24);

                end case;

            -- ------------------------------------------------
            -- READ (load)
            -- Reads the requested bytes, then sign- or
            -- zero-extends to 32 bits depending on mem_signed.
            -- ------------------------------------------------
            elsif mem_read = '1' then

                case mem_size is

                    -- lb / lbu — single byte
                    when "00" =>
                        b0       := mem(byte_addr);
                        sign_bit := b0(7);
                        if mem_signed = '1' then
                            -- sign-extend: replicate bit 7 into [31:8]
                            read_data <= (31 downto 8 => sign_bit) & b0;
                        else
                            -- zero-extend: pad with zeros
                            read_data <= (31 downto 8 => '0') & b0;
                        end if;

                    -- lh / lhu — halfword (little-endian: low byte first)
                    when "01" =>
                        b0       := mem(byte_addr);
                        b1       := mem(byte_addr + 1);
                        sign_bit := b1(7);  -- MSB of the halfword
                        if mem_signed = '1' then
                            read_data <= (31 downto 16 => sign_bit) & b1 & b0;
                        else
                            read_data <= (31 downto 16 => '0') & b1 & b0;
                        end if;

                    -- lw — full word (little-endian)
                    when others =>
                        b0 := mem(byte_addr);
                        b1 := mem(byte_addr + 1);
                        b2 := mem(byte_addr + 2);
                        b3 := mem(byte_addr + 3);
                        read_data <= b3 & b2 & b1 & b0;

                end case;

            end if;  -- mem_write / mem_read

        end if;  -- rising_edge
    end process mem_access;

end architecture behavioral;
