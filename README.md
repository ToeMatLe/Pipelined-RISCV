# Pipelined RISC-V with Hazard Detection and Forwarding

A lightweight 5-stage RV32I-style soft-core processor written in SystemVerilog.

This project implements a pipelined RISC-V datapath with hazard detection, register forwarding, branch/jump flushing, and a register file that supports same-cycle write/read bypassing. The goal of this project is to build up a working pipelined CPU piece by piece while keeping the design readable and easy to debug.

## Features

- RV32I-style ALU operations
- Five-stage pipeline
- IF, ID, EX, MEM, and WB pipeline registers
- Load-use hazard detection
- Pipeline stalling and bubble insertion
- EX/MEM and MEM/WB forwarding
- Store-data forwarding
- Branch compare forwarding
- Register file write/read bypassing
- Branch and jump flushing
- Word-based instruction memory and data memory

## Pipelining

The processor uses the classic 5-stage pipeline:

```text
Instruction Fetch -> Instruction Decode -> Execute -> Memory Access -> Write Back
```

Each stage passes its needed values and control signals into the next stage through pipeline registers.

## Instruction Fetch Stage

During the Instruction Fetch stage, the program counter provides the address of the current instruction. The instruction memory uses that address to output the instruction for the current cycle.

The IF/ID pipeline register stores:

- current PC
- PC + 4
- fetched instruction

If the pipeline needs to stall, the PC and IF/ID register are frozen. If a branch or jump redirects the PC, the IF/ID register is flushed with a NOP.

## Instruction Decode Stage

During the Instruction Decode stage, the instruction fields are split into opcode, destination register, source registers, funct3, and funct7.

The control unit uses those fields to generate the control signals for the rest of the pipeline. This stage also reads `rs1` and `rs2` from the register file and generates the immediate value for the instruction.

The ID/EX pipeline register stores:

- PC
- PC + 4
- register data
- immediate
- register addresses
- opcode/funct information
- control signals

This stage also connects to the hazard detection unit. If a load-use hazard is detected, ID/EX is cleared into a bubble while IF/ID and PC are held.

## Execute Stage

During the Execute stage, the ALU performs the operation selected by the control unit.

This stage also handles forwarding. If an instruction needs a value that has not been written back yet, the forwarding unit can choose the newer value from either:

- EX/MEM
- MEM/WB

Forwarding is used for ALU operands, branch comparisons, store data, and JALR target calculation.

Branch and jump targets are also calculated in this stage. If a branch or jump is taken, the pipeline redirects the program counter and flushes the wrong-path instruction in IF/ID.

## Memory Access Stage

During the Memory Access stage, load and store instructions access data memory.

For stores, the value being written to memory can come through forwarding. This matters for code like:

```asm
add x5, x1, x2
sw  x5, 0(x0)
```

Without store-data forwarding, the store could write the old value of `x5`. With forwarding, it writes the result from the newer instruction.

The EX/MEM pipeline register carries the ALU result, store data, destination register, and memory control signals into this stage.

## Write Back Stage

During the Write Back stage, the processor writes the final result back into the register file when `regWrite` is enabled.

The write-back value can come from:

- ALU result
- memory read data
- PC + 4 for jump/link instructions

The register file also supports same-cycle write/read bypassing. If one instruction writes a register in WB while another instruction reads that same register in ID, the read gets the new write-back value instead of the old stored value.

## Hazard Detection

### Load-Use Hazard

A load-use hazard happens when the instruction right after a load needs the loaded value.

Example:

```asm
lw  x5, 0(x1)
add x6, x5, x2
```

Forwarding alone cannot fix this immediately because the load data is not ready until the memory stage. To handle this, the hazard detection unit stalls the pipeline for one cycle.

The stall does three things:

1. Freezes the PC.
2. Freezes IF/ID.
3. Inserts a bubble into ID/EX.

After that one-cycle wait, the loaded value can be forwarded from MEM/WB to the instruction that needs it.

### Normal Register Hazards

Most non-load register hazards do not need a stall.

Example:

```asm
add x5, x1, x2
sub x6, x5, x3
```

The `add` result is ready soon enough to be forwarded into the `sub` instruction. The forwarding unit handles this without pausing the pipeline.

### Control Hazards

Branches and jumps are resolved in the Execute stage.

The processor naturally fetches the next sequential instruction while waiting to know if a branch or jump redirects the PC. If the branch or jump is taken, the wrong-path instruction in IF/ID is flushed and the PC is redirected to the target address.

This is basically a simple static not-taken behavior: keep going forward unless EX says to redirect.

## Forwarding

The forwarding unit checks whether the instruction in EX needs a value that is currently in a later pipeline stage.

Forwarding priority is:

1. EX/MEM
2. MEM/WB
3. original register-file value

EX/MEM has priority because it is the newest matching result.

The forwarding unit does not forward load data from EX/MEM because a load result is not ready there yet. Load-use hazards are handled by the hazard detection unit first, then MEM/WB forwarding handles the loaded value.

## Supported Instruction Groups

The current design supports a useful RV32I-style subset:

- R-type ALU instructions
- I-type ALU instructions
- `lw`
- `sw`
- branch instructions
- `lui`
- `auipc`
- `jal`
- `jalr`
