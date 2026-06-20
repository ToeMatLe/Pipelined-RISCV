`timescale 1ns / 1ps
// need clk becasue we need previous values
module ProgramCounter (
    input logic clk,
    input logic reset_n,
    input logic stall,
    input logic redirect,
    input logic [31:0] redirect_target,
    output logic [31:0] outputPCAddress
);

logic [31:0] currentPCAddress;
logic [31:0] nextPC;

// Redirect > Stall > Sequential priority.
// An older branch/jump in EX must override a stall on a younger instruction.
always_comb begin
    if (redirect) begin
        nextPC = redirect_target;
    end else if (stall) begin
        nextPC = currentPCAddress;
    end else begin
        nextPC = currentPCAddress + 4;
    end
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
