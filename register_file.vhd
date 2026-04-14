-- INPUTS:
--   clk       : system clock (1 GHz per testbench spec)
--   rs1_addr  : 5-bit address of first source register
--   rs2_addr  : 5-bit address of second source register
--   rd_addr   : 5-bit address of destination register
--   rd_data   : 32-bit value to write into rd
--   reg_write : write-enable; '1' = write rd on rising edge
--
-- OUTPUTS:
--   rs1_data  : 32-bit value read from rs1 (combinational)
--   rs2_data  : 32-bit value read from rs2 (combinational)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity register_file is
    port (
        clk  : in  std_logic;

        -- Read ports (combinational:updated any time addr changes)
        rs1_addr  : in  std_logic_vector(4 downto 0);
        rs2_addr  : in  std_logic_vector(4 downto 0);
        rs1_data  : out std_logic_vector(31 downto 0);
        rs2_data  : out std_logic_vector(31 downto 0);

        -- Write port (synchronous:commits on rising clock edge)
        rd_addr   : in  std_logic_vector(4 downto 0);
        rd_data   : in  std_logic_vector(31 downto 0);
        reg_write : in  std_logic
    );
end entity register_file;

architecture behavioral of register_file is

    -- Register bank: 32 registers, each 32 bits wide
    type reg_array is array(0 to 31) of std_logic_vector(31 downto 0);

    signal regs : reg_array := (others => (others => '0'));

begin

    -- WRITE PORT: synchronous, rising-edge triggered
    -- On every rising clock edge, if reg_write = '1' and destination is not x0
    -- -> the value on rd_data is latched into the addressed register
  
    write_port : process(clk)
    begin
        if rising_edge(clk) then
            if reg_write = '1' and rd_addr /= "00000" then
                regs(to_integer(unsigned(rd_addr))) <= rd_data;
            end if;
        end if;
    end process write_port;

    -- READ PORTS: fully combinational (asynchronous)
    -- The read value is directly from the register array
    --it updates whenever rs1_addr or rs2_addr changes without waiting for a clock edge
    rs1_data <= regs(to_integer(unsigned(rs1_addr)));
    rs2_data <= regs(to_integer(unsigned(rs2_addr)));

end architecture behavioral;

