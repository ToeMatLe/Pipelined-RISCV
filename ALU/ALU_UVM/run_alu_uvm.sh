#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

# UCLA school server VCS/Verdi setup, matching the class wrapper scripts.
export SYNOPSYS="${SYNOPSYS:-/usr/apps/synopsys}"
export VCS_HOME="${VCS_HOME:-/home/apps3/Synopsys/VCS/vT-2022.06-1}"
export VERDI_HOME="${VERDI_HOME:-/home/apps3/Synopsys/Verdi/vT-2022.06-SP1}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-5281@lm-cadence.seas.ucla.edu}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-1784@lm-synopsys.seas.ucla.edu}"
export PATH="$VCS_HOME/bin:$VCS_HOME/amd64/bin:$PATH"

if command -v xrun >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Cadence Xcelium
    xrun -64bit -sv -uvm -f ALU/ALU_UVM/alu_uvm.f -top alu_tb_top
elif command -v vcs >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Synopsys VCS
    # -ntb_opts uvm compiles the UVM library
    # novas/pli for verdi/fsdb
    VCS_PLI_ARGS=()
    if [ -n "${VERDI_HOME:-}" ] &&
       [ -f "$VERDI_HOME/share/PLI/VCS/linux64/novas.tab" ] &&
       [ -f "$VERDI_HOME/share/PLI/VCS/linux64/pli.a" ]; then
        VCS_PLI_ARGS=(
            -P "$VERDI_HOME/share/PLI/VCS/linux64/novas.tab"
            "$VERDI_HOME/share/PLI/VCS/linux64/pli.a"
        )
    elif [ -n "${VERDI_HOME:-}" ] &&
       [ -f "$VERDI_HOME/share/PLI/VCS/linux/novas.tab" ] &&
       [ -f "$VERDI_HOME/share/PLI/VCS/linux/pli.a" ]; then
        VCS_PLI_ARGS=(
            -P "$VERDI_HOME/share/PLI/VCS/linux/novas.tab"
            "$VERDI_HOME/share/PLI/VCS/linux/pli.a"
        )
    fi
    # 64-bit vcs, sytemverilog, emable uvm library, set timescale, generate debug info for Verdi, enable kdb, compile the files in alu_uvm.f, set top module to alu_tb_top, and run the simv
    vcs \
        "${VCS_PLI_ARGS[@]}" \
        -full64 -sverilog -ntb_opts uvm -timescale=1ns/1ps \
        -debug_access+all -kdb \
        -f ALU/ALU_UVM/alu_uvm.f \
        -top alu_tb_top \
        -R
elif command -v vsim >/dev/null 2>&1; then
    # Compile and run the UVM testbench using Mentor Graphics Questa/ModelSim
    vlog -sv -f ALU/ALU_UVM/alu_uvm.f
    vsim -c alu_tb_top -do "run -all; quit -f"
else
    echo "No UVM simulator found. Install/use Xcelium (xrun), VCS, or Questa/ModelSim (vlog/vsim)."
    exit 1
fi
