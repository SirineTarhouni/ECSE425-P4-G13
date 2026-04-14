# =============================================================
# testbench.tcl
# ECSE 425 - Pipelined Processor Testbench
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
# -------------------------------------------------------------
vcom -2008 alu.vhd
vcom -2008 register_file.vhd
vcom -2008 control_unit.vhd
vcom -2008 imm_gen.vhd
vcom -2008 instruction_mem.vhd
vcom -2008 data_mem.vhd
vcom -2008 processor.vhd

# -------------------------------------------------------------
# 2. Elaborate — -t 1ps gives ps resolution so 500ps clock works
# -------------------------------------------------------------
vsim -t 1ps work.processor

# -------------------------------------------------------------
# 3. Clock (1 GHz) and reset
# -------------------------------------------------------------
force -freeze /processor/clk 1 0, 0 500ps -repeat 1ns
force -freeze /processor/reset 1 0
run 5ns
force -freeze /processor/reset 0

# -------------------------------------------------------------
# 4. Run 10,000 clock cycles
# -------------------------------------------------------------
run 10000ns

# =============================================================
# Helper: convert an unsigned integer to a zero-padded N-bit
#         binary string.
# =============================================================
proc to_bin {int_val bits} {
    set result ""
    for {set b [expr {$bits - 1}]} {$b >= 0} {incr b -1} {
        if {$int_val & (1 << $b)} {
            append result "1"
        } else {
            append result "0"
        }
    }
    return $result
}

# =============================================================
# 5. Dump data memory -> memory.txt
#    8192 words, each word = 4 bytes little-endian
# =============================================================
set MEM_WORDS 8192
set mem_file [open "memory.txt" w]

for {set i 0} {$i < $MEM_WORDS} {incr i} {
    set byte_addr [expr {$i * 4}]

    set b0 [examine -radix unsigned /processor/dmem/mem($byte_addr)]
    set b1 [examine -radix unsigned /processor/dmem/mem([expr {$byte_addr + 1}])]
    set b2 [examine -radix unsigned /processor/dmem/mem([expr {$byte_addr + 2}])]
    set b3 [examine -radix unsigned /processor/dmem/mem([expr {$byte_addr + 3}])]

    set b0 [string trim $b0]
    set b1 [string trim $b1]
    set b2 [string trim $b2]
    set b3 [string trim $b3]

    # Little-endian: b3=MSB, b0=LSB
    set word_bin "[to_bin $b3 8][to_bin $b2 8][to_bin $b1 8][to_bin $b0 8]"
    puts $mem_file $word_bin
}

close $mem_file
puts "memory.txt written ($MEM_WORDS words)."

# =============================================================
# 6. Dump register file -> register_file.txt
#    32 registers, each 32 bits
# =============================================================
set REG_COUNT 32
set rf_file [open "register_file.txt" w]

for {set i 0} {$i < $REG_COUNT} {incr i} {
    set val [examine -radix unsigned /processor/rf/regs($i)]
    set val [string trim $val]
    puts $rf_file [to_bin $val 32]
}

close $rf_file
puts "register_file.txt written ($REG_COUNT registers)."

puts ""
puts "=========================================="
puts " Simulation complete."
puts " Output files: memory.txt, register_file.txt"
puts "=========================================="
