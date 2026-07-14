#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# UCLA school server VCS/Verdi setup.
export SYNOPSYS="${SYNOPSYS:-/usr/apps/synopsys}"
export VCS_HOME="${VCS_HOME:-/home/apps3/Synopsys/VCS/vT-2022.06-1}"
export VERDI_HOME="${VERDI_HOME:-/home/apps3/Synopsys/Verdi/vT-2022.06-SP1}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-5281@lm-cadence.seas.ucla.edu}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-1784@lm-synopsys.seas.ucla.edu}"
export PATH="$VCS_HOME/bin:$VCS_HOME/amd64/bin:$PATH"

if ! command -v vcs >/dev/null 2>&1; then
    echo "Could not find VCS on PATH."
    exit 1
fi

SV_SOURCES=(
    "Program Counter/ProgramCounter.sv"
    "Instruction Memory/InstructionMem.sv"
    "Register File/RegisterFile.sv"
    "Control Unit/ControlUnit.sv"
    "ALU/ALU.sv"
    "Hazard and Forwarding/Forwarding_Unit.sv"
    "Hazard and Forwarding/Hazard_Detecton_Unit.sv"
    "Cache/MSI_Controller.sv"
    "Cache/L1DataCache.sv"
    "Data Memory/DataMem.sv"
    "Pipelined Data Path/DataPath.sv"
    "Benchmarks/cpu_speed_benchmark_tb.sv"
)

vcs \
    -full64 -sverilog -timescale=1ns/1ps \
    -debug_access+all -kdb \
    +incdir+. \
    +incdir+ALU \
    +incdir+Cache \
    +incdir+"Control Unit" \
    +incdir+"Data Memory" \
    +incdir+"Hazard and Forwarding" \
    +incdir+"Instruction Memory" \
    +incdir+"Pipelined Data Path" \
    +incdir+"Program Counter" \
    +incdir+"Register File" \
    "${SV_SOURCES[@]}" \
    -top cpu_speed_benchmark_tb \
    -o cpu_speed_benchmark_simv \
    -R
