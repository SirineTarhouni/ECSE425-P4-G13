-- INPUTS:
--   op_a    : first operand (rs1, or PC for AUIPC)
--   op_b    : second operand (rs2, or sign-extended immediate)
--   alu_op  : 4-bit control code selecting the operation
--
-- OUTPUT:
--   result  : 32-bit result of the operation

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
  port (
    op_a    : in  std_logic_vector(31 downto 0);
    op_b    : in  std_logic_vector(31 downto 0);
    alu_op  : in  std_logic_vector(3 downto 0);
    result  : out std_logic_vector(31 downto 0)
  );
end entity alu;

architecture behavioral of alu is
  
  -- ALU operation codes (alu_op encoding)
  -- Values control unit will produce
  constant ALU_ADD  : std_logic_vector(3 downto 0) := "0000"; -- add, addi, lw, sw, auipc, jalr, jal
  constant ALU_SUB  : std_logic_vector(3 downto 0) := "0001"; -- sub, beq/bne/blt/bge comparison base
  constant ALU_AND  : std_logic_vector(3 downto 0) := "0010"; -- and, andi
  constant ALU_OR   : std_logic_vector(3 downto 0) := "0011"; -- or,  ori
  constant ALU_XOR  : std_logic_vector(3 downto 0) := "0100"; -- xor, xori
  constant ALU_SLL  : std_logic_vector(3 downto 0) := "0101"; -- sll, slli
  constant ALU_SRL  : std_logic_vector(3 downto 0) := "0110"; -- srl, srli
  constant ALU_SRA  : std_logic_vector(3 downto 0) := "0111"; -- sra, srai
  constant ALU_SLT  : std_logic_vector(3 downto 0) := "1000"; -- slt, slti  (signed)
  constant ALU_SLTU : std_logic_vector(3 downto 0) := "1001"; -- sltu, sltiu (unsigned)
  constant ALU_LUI  : std_logic_vector(3 downto 0) := "1010"; -- lui (pass op_b through)
  constant ALU_MUL  : std_logic_vector(3 downto 0) := "1011"; -- mul

  -- Signals for intermediate computations
  signal a_signed    : signed(31 downto 0);
  signal b_signed    : signed(31 downto 0);
  signal a_unsigned  : unsigned(31 downto 0);
  signal b_unsigned  : unsigned(31 downto 0);

  -- Shift amount: only the low 5 bits of op_b are used
  signal shamt  : natural range 0 to 31;

  -- For MUL, we need a 64-bit buffer to hold the full product before shortening to the low 32 bits
  signal mul_result : signed(63 downto 0);

begin 
    a_signed  <= signed(op_a);
    b_signed  <= signed(op_b);
    a_unsigned <= unsigned(op_a);
    b_unsigned <= unsigned(op_b);

  -- The shift amount is always the lower 5 bits of op_b
  shamt <= to_integer(unsigned(op_b(4 downto 0)));

  -- Main ALU operation select

  process(alu_op, op_a, op_b, a_signed, b_signed, a_unsigned, b_unsigned, shamt, mul_result)
    begin
      case alu_op is 
        -- ADD: used by add, addi, load/store address calc, auipc (PC + upper-immediate), jal/jalr
        when ALU_ADD =>
          result <= std_logic_vector(a_signed + b_signed);
      
        -- SUB: used by sub instruction (branches do NOT use the ALU for their comparison)
        when ALU_SUB =>
          result <= std_logic_vector(a_signed - b_signed);
    
        -- AND / OR / XOR: bitwise logical operations
        when ALU_AND =>
          result <= op_a and op_b;
        when ALU_OR =>
          result <= op_a or op_b;
        when ALU_XOR =>
          result <= op_a xor op_b;

        -- SLL: Shift Left Logical, shifts op_a left by shamt positions, filling with 0s
        when ALU_SLL =>
          result <= std_logic_vector(shift_left(a_unsigned, shamt));

        -- SRL: Shift Right Logical, shifts op_a right by shamt positions, filling with 0s
        when ALU_SRL =>
          result <= std_logic_vector(shift_right(a_unsigned, shamt));

        -- SRA: Shift Right Arithmetic, shifts right but replicates the sign bit (MSB) into the vacated positions
        when ALU_SRA =>
          result <= std_logic_vector(shift_right(a_signed, shamt));

        -- SLT: Set Less Than (signed), outputs 1 if op_a < op_b as signed integers, else 0 (slt, slti)
        when ALU_SLT =>
          if a_signed < b_signed then
            result <= (others => '0');
            result(0) <= '1';
          else
            result <= (others => '0');
          end if;

        -- SLTU: Set Less Than Unsigned, both operands as unsigned (sltu, sltiu)
        when ALU_SLTU =>
          if a_unsigned < b_unsigned then
            result <= (others => '0');
            result(0) <= '1';
          else
            result <= (others => '0');
          end if;

        -- LUI: Load Upper Immediate, the immediate already in op_b
        when ALU_LUI =>
          result <= op_b;

        -- MUL: Multiply, produce a 64-bit product, we only keep the lower
        when ALU_MUL =>
          mul_result  <= a_signed * b_signed;
          result  <= std_logic_vector(mul_result(31 downto 0));

        -- Default: output zero for any undefined opcode
        when others =>
          result <= (others => '0');

      end case;
    end process;
end architecture behavioral;


