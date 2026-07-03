#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

# UCLA school server VCS setup
if [ -d /home/apps3/Synopsys/VCS/vT-2022.06-1 ]; then
    export VCS_HOME=/home/apps3/Synopsys/VCS/vT-2022.06-1
    export LM_LICENSE_FILE=5281@lm-cadence.seas.ucla.edu
    export SNPSLMD_LICENSE_FILE=1784@lm-synopsys.seas.ucla.edu
    export PATH=$VCS_HOME/bin:$PATH
fi

if command -v xrun >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Cadence Xcelium
    xrun -64bit -sv -uvm -f ALU/ALU_UVM/alu_uvm.f -top alu_tb_top
elif command -v vcs >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Synopsys VCS
    # -ntb_opts uvm compiles the UVM library
    vcs -full64 -sverilog -ntb_opts uvm -timescale=1ns/1ps -f ALU/ALU_UVM/alu_uvm.f -top alu_tb_top -R
elif command -v vsim >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Mentor Graphics Questa/ModelSim
    vlog -sv -f ALU/ALU_UVM/alu_uvm.f
    vsim -c alu_tb_top -do "run -all; quit -f"
else
    echo "No UVM simulator found. Install/use Xcelium (xrun), VCS, or Questa/ModelSim (vlog/vsim)."
    exit 1
fi
