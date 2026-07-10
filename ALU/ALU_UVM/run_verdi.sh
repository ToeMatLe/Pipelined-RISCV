#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

# UCLA school server Verdi setup, matching the class wrapper scripts.
export VERDI_HOME="${VERDI_HOME:-/home/apps3/Synopsys/Verdi/vT-2022.06-SP1}"
export VCS_HOME="${VCS_HOME:-/home/apps3/Synopsys/VCS/vT-2022.06-1}"
export SYNOPSYS="${SYNOPSYS:-/usr/apps/synopsys}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-5281@lm-cadence.seas.ucla.edu}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-1784@lm-synopsys.seas.ucla.edu}"
export PATH="$VERDI_HOME/bin:$VCS_HOME/bin:$VCS_HOME/amd64/bin:$PATH"

if ! command -v verdi >/dev/null 2>&1; then
    echo "Could not find Verdi on PATH."
    exit 1
fi

if [ "$#" -gt 0 ]; then
    exec verdi "$@"
fi

if [ -f alu_uvm.fsdb ]; then
    exec verdi -ssf alu_uvm.fsdb
elif [ -d simv.daidir ]; then
    exec verdi -dbdir simv.daidir
else
    echo "No alu_uvm.fsdb or simv.daidir found. Run ALU/ALU_UVM/run_alu_uvm.sh first."
    exit 1
fi
