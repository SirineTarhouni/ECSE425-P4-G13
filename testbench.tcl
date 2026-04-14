# =============================================================
# testbench.tcl
# ECSE 425 - Pipelined Processor Testbench
#
# Usage (from ModelSim/Questa console, with working directory
# set to the folder containing all .vhd files and program.txt):
#
#   do testbench.tcl
#
# What this script does:
#   1. Compiles all VHDL source files
#   2. Elaborates the top-level processor entity
#   3. Applies reset then runs for 10,000 clock cycles at 1 GHz
#   4. Writes final data memory contents  -> memory.txt
#      (8192 lines, one 32-bit word per line, binary)
#   5. Writes final register file contents -> register_file.txt
#      (32 lines, one 32-bit word per line, binary)
# =============================================================

# -------------------------------------------------------------
# 0. Set up the work library
# -------------------------------------------------------------
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# -------------------------------------------------------------
# 1. Compile all VHDL source files
#    Order matters: components before the top level.
# -------------------------------------------------------------
vcom -2008 alu.vhd
vcom -2008 register_file.vhd
vcom -2008 control_unit.vhd
vcom -2008 imm_gen.vhd
vcom -2008 instruction_mem.vhd
vcom -2008 data_mem.vhd
vcom -2008 processor.vhd

# -------------------------------------------------------------
# 2. Elaborate (load) the top-level design.
#    instruction_mem reads program.txt during elaboration, so
#    program.txt must already be present in the working directory.
# -------------------------------------------------------------
vsim -t 1ns work.processor

# -------------------------------------------------------------
# 3. Clock and reset
#    Clock period = 1 ns  →  1 GHz
#    Reset is held high for the first 5 ns then released.
# -------------------------------------------------------------

# Drive clock: 1 ns period (500 ps high, 500 ps low)
force -freeze /processor/clk 1 0, 0 500ps -repeat 1ns

# Assert synchronous reset for the first 5 clock cycles
force -freeze /processor/reset 1 0
run 5ns
force -freeze /processor/reset 0

# -------------------------------------------------------------
# 4. Run for 10,000 clock cycles
#    Each cycle = 1 ns  →  10,000 ns total after reset
# -------------------------------------------------------------
run 10000ns

# =============================================================
# 5. Dump data memory to memory.txt
#
#    The data_mem instance inside processor is named "dmem"
#    (see processor.vhd).  Its internal byte array signal is
#    "mem".  We read all 32768 bytes and reassemble them into
#    8192 32-bit little-endian words, one per line in binary.
# =============================================================

set MEM_WORDS 8192
set mem_file [open "memory.txt" w]

for {set i 0} {$i < $MEM_WORDS} {incr i} {
    set byte_addr [expr {$i * 4}]

    # examine returns a string like "8'b00000000" or "8'hXX"
    # We use -radix binary to get a binary string.
    set b0 [examine -radix binary /processor/dmem/mem($byte_addr)]
    set b1 [examine -radix binary /processor/dmem/mem([expr {$byte_addr + 1}])]
    set b2 [examine -radix binary /processor/dmem/mem([expr {$byte_addr + 2}])]
    set b3 [examine -radix binary /processor/dmem/mem([expr {$byte_addr + 3}])]

    # Strip any width prefix (e.g. "8'b") that ModelSim may add
    # and pad/trim each byte to exactly 8 bits.
    set b0 [string range $b0 end-7 end]
    set b1 [string range $b1 end-7 end]
    set b2 [string range $b2 end-7 end]
    set b3 [string range $b3 end-7 end]

    # Little-endian: byte 3 is MSB, byte 0 is LSB → b3 b2 b1 b0
    puts $mem_file "${b3}${b2}${b1}${b0}"
}

close $mem_file
puts "memory.txt written ($MEM_WORDS words)."

# =============================================================
# 6. Dump register file to register_file.txt
#
#    The register_file instance inside processor is named
#    "rf" (see processor.vhd).  Its internal array signal is
#    "regs".  We read all 32 registers.
# =============================================================

set REG_COUNT 32
set rf_file [open "register_file.txt" w]

for {set i 0} {$i < $REG_COUNT} {incr i} {
    set val [examine -radix binary /processor/rf/regs($i)]

    # Pad / trim to exactly 32 bits
    set val [string range $val end-31 end]
    # If the string is shorter than 32 chars (e.g. for x0 = 0)
    # pad with leading zeros
    set val [format "%032s" $val]
    set val [string map {" " "0"} $val]

    puts $rf_file $val
}

close $rf_file
puts "register_file.txt written ($REG_COUNT registers)."

puts ""
puts "=========================================="
puts " Simulation complete."
puts " Output files: memory.txt, register_file.txt"
puts "=========================================="
