-- ============================================================
-- imm_gen.vhd
-- ECSE 425 - Pipelined Processor
--
-- Pure combinational immediate generator.  Reads the full
-- 32-bit instruction word and reconstructs the sign- (or
-- zero-) extended 32-bit immediate value appropriate for
-- that instruction's format.
--
-- RISC-V defines six immediate encodings:
--
--   I-type  : loads, ALU-immediate, jalr
--   S-type  : stores
--   B-type  : branches  (same bits as S but different layout)
--   U-type  : lui, auipc
--   J-type  : jal
--   R-type  : no immediate (output is 0)
--
-- All sign extensions replicate instruction bit 31 (the MSB).
-- The two exceptions that zero-extend are lbu / lhu; however,
-- their IMMEDIATE (the address offset) is still sign-extended
-- exactly like any other I-type load — the zero-extension
-- applies only to the loaded *data* value, which is handled
-- in the memory stage, not here.
--
-- INPUTS:
--   instruction : full 32-bit instruction word (from IF/ID.IR)
--
-- OUTPUTS:
--   imm_out     : 32-bit sign-extended (or zero-extended for
--                 U-type lower 12 bits) immediate value
-- ============================================================

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

    -- Opcode field — drives format selection.
    alias opcode : std_logic_vector(6 downto 0) is instruction(6 downto 0);

    -- Sign bit, replicated for extensions.
    alias sign : std_logic is instruction(31);

begin

    process(instruction)
    begin

        case opcode is

            -- --------------------------------------------------------
            -- I-TYPE: addi, xori, ori, andi, slti, sltiu,
            --         slli, srli, srai,
            --         lb, lh, lw, lbu, lhu,
            --         jalr
            --
            -- Immediate bits: instr[31:20]
            -- imm[11:0]  = instr[31:20]
            -- imm[31:12] = sign (instr[31]) replicated 20 times
            -- --------------------------------------------------------
            when "0010011" |   -- I-type ALU  (addi, xori, …)
                 "0000011" |   -- loads       (lb, lh, lw, lbu, lhu)
                 "1100111" =>  -- jalr

                imm_out <= (31 downto 12 => sign) & instruction(31 downto 20);

            -- --------------------------------------------------------
            -- S-TYPE: sb, sh, sw
            --
            -- Immediate bits are split:
            --   imm[11:5] = instr[31:25]
            --   imm[4:0]  = instr[11:7]
            --   imm[31:12] = sign replicated
            -- --------------------------------------------------------
            when "0100011" =>  -- stores

                imm_out <= (31 downto 12 => sign)
                         & instruction(31 downto 25)   -- imm[11:5]
                         & instruction(11 downto 7);   -- imm[4:0]

            -- --------------------------------------------------------
            -- B-TYPE: beq, bne, blt, bge, bltu, bgeu
            --
            -- Immediate encodes a byte offset; the assembler already
            -- accounts for the x2 scaling, but the hardware must
            -- reassemble the scrambled bits:
            --
            --   imm[12]   = instr[31]
            --   imm[11]   = instr[7]
            --   imm[10:5] = instr[30:25]
            --   imm[4:1]  = instr[11:8]
            --   imm[0]    = '0'           (branches always word-aligned)
            --   imm[31:13] = sign replicated
            --
            -- Note: the pipeline adds this immediate to NPC (PC+4)
            -- in the EX stage to form the branch target.
            -- --------------------------------------------------------
            when "1100011" =>  -- branches

                imm_out <= (31 downto 13 => sign)
                         & sign                        -- imm[12]
                         & instruction(7)              -- imm[11]
                         & instruction(30 downto 25)   -- imm[10:5]
                         & instruction(11 downto 8)    -- imm[4:1]
                         & '0';                        -- imm[0]

            -- --------------------------------------------------------
            -- U-TYPE: lui, auipc
            --
            -- The 20-bit immediate occupies instr[31:12] and is
            -- placed in the *upper* 20 bits of the result; the lower
            -- 12 bits are zeroed.  No sign extension is needed because
            -- the entire upper half carries the sign already.
            --
            --   imm[31:12] = instr[31:12]
            --   imm[11:0]  = 0x000
            -- --------------------------------------------------------
            when "0110111" |   -- lui
                 "0010111" =>  -- auipc

                imm_out <= instruction(31 downto 12) & (11 downto 0 => '0');

            -- --------------------------------------------------------
            -- J-TYPE: jal
            --
            -- Immediate bits are heavily scrambled in the encoding:
            --
            --   imm[20]    = instr[31]
            --   imm[10:1]  = instr[30:21]
            --   imm[11]    = instr[20]
            --   imm[19:12] = instr[19:12]
            --   imm[0]     = '0'           (jumps always word-aligned)
            --   imm[31:21] = sign replicated
            -- --------------------------------------------------------
            when "1101111" =>  -- jal

                imm_out <= (31 downto 21 => sign)
                         & sign                        -- imm[20]
                         & instruction(19 downto 12)   -- imm[19:12]
                         & instruction(20)             -- imm[11]
                         & instruction(30 downto 21)   -- imm[10:1]
                         & '0';                        -- imm[0]

            -- --------------------------------------------------------
            -- R-TYPE and anything else: no immediate field.
            -- Output zero so the datapath is not affected.
            -- --------------------------------------------------------
            when others =>

                imm_out <= (others => '0');

        end case;
    end process;

end architecture behavioral;
