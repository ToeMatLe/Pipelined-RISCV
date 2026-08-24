#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v verilator >/dev/null 2>&1; then
    echo "Could not find Verilator on PATH."
    exit 1
fi

BENCH_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/riscv-hazard-benchmark.XXXXXX")"
trap 'rm -rf -- "$BENCH_TMP_DIR"' EXIT

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

INCLUDE_DIRS=(
    -I.
    -IALU
    -ICache
    "-IControl Unit"
    "-IData Memory"
    "-IHazard and Forwarding"
    "-IInstruction Memory"
    "-IPipelined Data Path"
    "-IProgram Counter"
    "-IRegister File"
)

run_case() {
    local forwarding_enabled="$1"
    local case_name="$2"
    local build_dir="$BENCH_TMP_DIR/$case_name"
    local log_file="$BENCH_TMP_DIR/$case_name.log"

    verilator --binary --timing -Wno-fatal \
        "${INCLUDE_DIRS[@]}" \
        --Mdir "$build_dir" \
        --top-module cpu_speed_benchmark_tb \
        -GUSE_L1_CACHE=0 \
        -GENABLE_FORWARDING="$forwarding_enabled" \
        "${SV_SOURCES[@]}" >/dev/null

    "$build_dir/Vcpu_speed_benchmark_tb" | tee "$log_file"
}

echo "Running interlocked baseline (forwarding disabled)..."
run_case 0 baseline

echo "Running optimized pipeline (forwarding enabled)..."
run_case 1 forwarding

BASELINE_CYCLES="$(awk '/Measured cycles/ {print $4}' "$BENCH_TMP_DIR/baseline.log")"
FORWARDING_CYCLES="$(awk '/Measured cycles/ {print $4}' "$BENCH_TMP_DIR/forwarding.log")"
BASELINE_CPI="$(awk '/^CPI/ {print $3}' "$BENCH_TMP_DIR/baseline.log")"
FORWARDING_CPI="$(awk '/^CPI/ {print $3}' "$BENCH_TMP_DIR/forwarding.log")"
REDUCTION="$(awk -v old="$BASELINE_CYCLES" -v new="$FORWARDING_CYCLES" \
    'BEGIN { printf "%.2f", 100.0 * (old - new) / old }')"

echo "--------------------------------------------------"
echo "HAZARD CPI COMPARISON"
echo "Interlocked baseline : $BASELINE_CYCLES cycles, CPI $BASELINE_CPI"
echo "With forwarding      : $FORWARDING_CYCLES cycles, CPI $FORWARDING_CPI"
echo "CPI reduction        : $REDUCTION%"
echo "--------------------------------------------------"

awk -v reduction="$REDUCTION" 'BEGIN {
    if (reduction + 0.0 < 24.5) {
        print "FAIL: CPI reduction did not round to the 25% target."
        exit 1
    }
}'
