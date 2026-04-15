-- RISC-V has 6 types of instrucoitns
--
--   I-type: load, ALU operatoins using immediates, and jalr (not J type!!)
--   S-type: store
--   B-type: branches
--   U-type: lui, auipc
--   J-type: jal
--   R-type: no imm
-- 
-- We sign extend all so that it can be 32 bits
-- INPUTS: instruction : full 32-bit instruction
--
-- OUTPUTS: imm_out     : 32-bit sign-extended (or zero-extended for U-type lower 12 bits) immediate value

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity imm_gen is
    port (
        instruction : in  std_logic_vector(31 downto 0);
        imm_out     : out std_logic_vector(31 downto 0)
    );
end entity imm_gen;

architecture behavioral of imm_gen is

    -- opcode is the last 7 bits (always at that position)
    alias opcode : std_logic_vector(6 downto 0) is instruction(6 downto 0);

    -- sign bit, replicated for extensions (sign extension)
    alias sign : std_logic is instruction(31);

begin

    process(instruction)
    begin

        case opcode is
            -- I-TYPE: immediate bits: instr[31:20], then sign extend to 32 bits
            when "0010011" | "0000011" | "1100111" =>  -- I-type ALU, loads, jalr
                imm_out <= (31 downto 12 => sign) & instruction(31 downto 20);

            -- S-TYPE: instr[31:25]& instr[11:7], then sign extension to 32 bits
            when "0100011" =>
                imm_out <= (31 downto 12 => sign) & instruction(31 downto 25) & instruction(11 downto 7);   -- imm[4:0]

            -- B-TYPE: instruction[31][7][30:25][11:8]"0", then sign extended
            -- the last "0" is becuase we shift that one bit to the left,
            -- addressing for branches does PC = PC + imm << 1, so last one always "0"
            --
            -- Note: we consider the different bits as said in teams in the assembler
            when "1100011" => 
                imm_out <= (31 downto 13 => sign) & sign & instruction(7) & instruction(30 downto 25)   & instruction(11 downto 8)  & '0';                  

            -- U-TYPE: instruction[31:12] << 12, so zero at the last 12 bits.
            -- we can sign extend but should already be 32 bits
            when "0110111" | "0010111" => 
                imm_out <= instruction(31 downto 12) & (11 downto 0 => '0');

            -- J-TYPE: insturction[31][19:12][20][30:21]"0", then sign extended
            
            when "1101111" =>  -- jal

                imm_out <= (31 downto 21 => sign) & sign & instruction(19 downto 12) & instruction(20) & instruction(30 downto 21) & '0';         

            -- R-TYPE and anything else: no immediate value
            -- so we output 0
            when others =>
                imm_out <= (others => '0');

        end case;
    end process;

end architecture behavioral;
