`timescale 1ns / 1ps
// need clk becasue we need previous values
module ProgramCounter (
    input logic clk,
    input logic reset_n,
    input logic stall,                   // New stall input to hold PC and IF/ID

    input logic jump_enable,
    input logic branEnable,
    input logic [31:0] branAddress, //address should be smaller
    input logic [31:0] jump_target_address, //address should be smaller
    output logic [31:0] outputPCAddress
);

logic [31:0] currentPCAddress;
logic [31:0] nextPC;

// Jump > Branch > Sequential priority
// If BranchEnable, go to the branch address, if not skip 4 to go to the next instruction
always_comb begin
    case (addressingMode)
        SEQ: nextPC = currentPCAddress + 4;
        JUMP: nextPC = jump_target_address;
        BRANCH: nextPC = branAddress;
        STALL: nextPC = currentPCAddress; // Hold the current PC address
        default: nextPC = currentPCAddress + 4; // Default to sequential
    endcase
end

// Resetter, in between clock cycles, combinational logic determines next PC address
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin // if reset goes low, set PC to 0
        currentPCAddress <= 32'b0;
    end else begin
        currentPCAddress <= nextPC;
    end
end
// output the current PC address
assign outputPCAddress = currentPCAddress;

endmodule
