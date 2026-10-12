# Vivado batch synthesis and implementation analysis for the RISC-V pipeline.
#
# Examples:
#   vivado -mode batch -source scripts/vivado_analyze.tcl
#   vivado -mode batch -source scripts/vivado_analyze.tcl \
#       -tclargs -mode impl -part xc7a35tcpg236-1 -period 8.0
#
# This is a non-project flow: it reads the RTL directly, creates timing
# constraints, runs synthesis, and writes reports under build/vivado/.

proc usage {} {
    puts "Usage: vivado -mode batch -source scripts/vivado_analyze.tcl -tclargs ?options?"
    puts ""
    puts "Options:"
    puts "  -top <module>       Synthesis top module (default: DataPath)"
    puts "  -part <part>        FPGA part (default: xc7a35tcpg236-1)"
    puts "  -period <ns>        Clock period in ns (default: 10.0)"
    puts "  -mode synth|impl    Stop after synthesis or run place/route (default: synth)"
    puts "  -help               Show this message"
}

# Defaults can be overridden with arguments after Vivado's -tclargs option.
set top_module   DataPath
set fpga_part    xc7a35tcpg236-1
set clock_period 10.0
set flow_mode    synth

for {set i 0} {$i < [llength $argv]} {incr i} {
    set option [lindex $argv $i]

    if {$option eq "-help"} {
        usage
        exit 0
    }

    if {$i + 1 >= [llength $argv]} {
        error "Missing value for $option"
    }

    incr i
    set value [lindex $argv $i]

    switch -- $option {
        -top    { set top_module $value }
        -part   { set fpga_part $value }
        -period { set clock_period $value }
        -mode   { set flow_mode $value }
        default { error "Unknown option '$option'. Use -help for usage." }
    }
}

if {$flow_mode ni {synth impl}} {
    error "-mode must be either 'synth' or 'impl'"
}

if {![string is double -strict $clock_period] || $clock_period <= 0.0} {
    error "-period must be a positive number in nanoseconds"
}

# Resolve every path relative to this script, so it can be launched from any
# working directory.
set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]
set build_dir  [file join $repo_root build vivado]
set report_dir [file join $build_dir reports]

file mkdir $build_dir
file mkdir $report_dir

# Include design sources only. Testbenches and UVM files are intentionally
# omitted because they are simulation code and are not synthesizable hardware.
set rtl_files [list \
    [file join $repo_root "Program Counter" ProgramCounter.sv] \
    [file join $repo_root "Instruction Memory" InstructionMem.sv] \
    [file join $repo_root "Register File" RegisterFile.sv] \
    [file join $repo_root "Control Unit" ControlUnit.sv] \
    [file join $repo_root "Hazard and Forwarding" Hazard_Detecton_Unit.sv] \
    [file join $repo_root "Hazard and Forwarding" Forwarding_Unit.sv] \
    [file join $repo_root ALU ALU.sv] \
    [file join $repo_root Cache MSI_Controller.sv] \
    [file join $repo_root Cache L1DataCache.sv] \
    [file join $repo_root "Data Memory" DataMem.sv] \
    [file join $repo_root "Pipelined Data Path" DataPath.sv] \
]

foreach rtl_file $rtl_files {
    if {![file exists $rtl_file]} {
        error "Missing RTL source: $rtl_file"
    }
}

puts "INFO: Top module   = $top_module"
puts "INFO: FPGA part    = $fpga_part"
puts "INFO: Clock period = $clock_period ns"
puts "INFO: Flow mode    = $flow_mode"
puts "INFO: Reports      = $report_dir"

# Read SystemVerilog and make typedef.svh visible to every source file.
read_verilog -sv $rtl_files

# Flattening with 'rebuilt' lets Vivado optimize across module boundaries while
# reconstructing useful hierarchy names for reports and schematic debugging.
synth_design \
    -top $top_module \
    -part $fpga_part \
    -include_dirs [list $repo_root] \
    -flatten_hierarchy rebuilt

# The CPU has one primary clock. A 10 ns period means a 100 MHz target.
create_clock \
    -name core_clk \
    -period $clock_period \
    [get_ports clk]

# reset_n is an asynchronous external control, so ordinary data-path setup and
# hold analysis should not try to time it relative to core_clk.
set_false_path -from [get_ports reset_n]

# Add a small margin for clock jitter and implementation variation.
set_clock_uncertainty 0.200 [get_clocks core_clk]

write_checkpoint -force [file join $build_dir post_synth.dcp]
write_verilog -force [file join $build_dir post_synth_netlist.v]
write_xdc -force [file join $build_dir post_synth_constraints.xdc]

# These are the reports an RTL/FPGA engineer commonly checks after synthesis:
# resource cost, timing feasibility, unconstrained paths, structural/design-rule
# problems, suspicious methodology patterns, high-fanout control nets, and an
# activity-estimated power baseline.
report_utilization \
    -hierarchical \
    -hierarchical_depth 3 \
    -file [file join $report_dir post_synth_utilization.rpt]

check_timing \
    -verbose \
    -file [file join $report_dir post_synth_timing_checks.rpt]

report_timing_summary \
    -delay_type min_max \
    -max_paths 10 \
    -report_unconstrained \
    -file [file join $report_dir post_synth_timing_summary.rpt]

report_drc \
    -file [file join $report_dir post_synth_drc.rpt]

report_methodology \
    -file [file join $report_dir post_synth_methodology.rpt]

report_high_fanout_nets \
    -max_nets 20 \
    -file [file join $report_dir post_synth_high_fanout.rpt]

report_power \
    -file [file join $report_dir post_synth_power.rpt]

if {$flow_mode eq "impl"} {
    # Placement and routing provide timing numbers that include physical wire
    # delay. These results are more meaningful than synthesis estimates.
    opt_design
    place_design
    phys_opt_design
    route_design

    write_checkpoint -force [file join $build_dir post_route.dcp]

    report_route_status \
        -file [file join $report_dir post_route_status.rpt]

    report_utilization \
        -hierarchical \
        -hierarchical_depth 3 \
        -file [file join $report_dir post_route_utilization.rpt]

    report_timing_summary \
        -delay_type min_max \
        -max_paths 10 \
        -report_unconstrained \
        -file [file join $report_dir post_route_timing_summary.rpt]

    report_drc \
        -file [file join $report_dir post_route_drc.rpt]

    report_methodology \
        -file [file join $report_dir post_route_methodology.rpt]

    report_power \
        -file [file join $report_dir post_route_power.rpt]
}

puts "INFO: Vivado $flow_mode analysis completed successfully."
puts "INFO: Review reports in $report_dir"
