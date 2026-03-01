`timescale 1ns / 1ps
`include "typedef.svh"

module DataPath (
    input logic clk,
    input logic reset_n
);
// IF stage: PC + Instruction fetch
// IF stage signals
logic [31:0] pc_if;
logic [31:0] instr_if;
logic [31:0] pc4_if;

assign pc4_if = pc_if + 32'd4;

// Control coming from hazard unit
logic stall_if;     // hold PC and IF/ID
logic flush_ifid;   // inject NOP into IF/ID (on redirect)

// Redirect from EX
logic redirect_ex;                  // Control signal to indicate EX stage has a jump/branch 
logic [31:0] redirect_target_ex;    // Target address from EX stage for jump/branch

// EX stage signals for jump/branch decisions
logic jump_taken_ex;
logic [31:0] jump_target_ex;
logic branch_taken_ex;
logic [31:0] branch_target_ex;

assign redirect_ex = jump_taken_ex | branch_taken_ex; //Both shouldnt happen at the same time (CAN DEFINE PRIORITY LATER)
assign flush_ifid = redirect_ex; // On redirect, we need to flush IF/ID to prevent wrong instruction from being decoded

// Program Counter
// We drive jump_enable/branEnable/targets from EX stage.
ProgramCounter programCounter (
    .clk(clk),
    .reset_n(reset_n),
    .jump_enable(jump_taken_ex),
    .branEnable(branch_taken_ex),
    .branAddress(branch_target_ex),
    .jump_target_address(jump_target_ex),
    .outputPCAddress(pc_if)
    .stall(stall_if),                   // New stall support
);

// Instruction memory
InstructionMem instructionMem (
    .address(pc_if),
    .instruction(instr_if)
);

// IF/ID pipeline register - holds PC, PC+4, and instruction for the ID stage
// At the end of this stage, the instruction is stored in the IF/ID pipeline register.
logic [31:0] ifid_pc;
logic [31:0] ifid_pc4;
logic [31:0] ifid_instr;

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ifid_pc    <= 32'b0;
        ifid_pc4   <= 32'b0;
        ifid_instr <= 32'h0000_0013; // NOP = addi x0,x0,0. Never insert garbage instruction on reset. This is for I-type instructions
    end else if (!stall_if) begin
        ifid_pc  <= pc_if;
        ifid_pc4 <= pc4_if;

        if (flush_ifid)
            ifid_instr <= 32'h0000_0013; // kill wrong-path instruction
        else
            ifid_instr <= instr_if;
    end
    // else: hold IF/ID on stall
end

endmodule