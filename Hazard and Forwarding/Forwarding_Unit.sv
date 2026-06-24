`timescale 1ns / 1ps
`include "typedef.svh"
// Fix Data Hazards with Forwarding without waiting for WB stage
module Forwarding_Unit (
    // Inputs from ID stage (current instruction forwarding)
    input logic [31:0] IDEX_rs1,
    input logic [31:0] IDEX_rs2,
    input logic [4:0] IDEX_rs1_addr,
    input logic [4:0] IDEX_rs2_addr,
    // Inputs from EX stage (one-stage ahead instruction forwarding)
    input logic EXMEM_regWrite,
    input logic [4:0] EXMEM_rd,
    input logic [31:0] EXMEM_aluResult,
    input logic [31:0] EXMEM_pc4,
    input writeBackSelect EXMEM_wbSelect,
    // Inputs from MEM stage (two-stage ahead instruction forwarding)
    input logic MEMWB_regWrite,
    input logic [4:0] MEMWB_rd,
    input logic [31:0] writeBackData,

    output logic [31:0] forwarded_rs1_EX,
    output logic [31:0] forwarded_rs2_EX
);

logic [31:0] EXMEM_forwardData;
logic EXMEM_canForward;

// EX/MEM can forward ALU-style results and PC+4 results.
// Load data is not ready in EX/MEM, so stall first using hazard detection unit
always_comb begin
    case (EXMEM_wbSelect)
        WB_PC4:  EXMEM_forwardData = EXMEM_pc4; // Forward PC+4 for JAL/JALR instructions
        default: EXMEM_forwardData = EXMEM_aluResult;
    endcase
end

// One stage ahead forwarding 
assign EXMEM_canForward = EXMEM_regWrite && (EXMEM_rd != 5'd0) && (EXMEM_wbSelect != WB_MEM);

always_comb begin
    forwarded_rs1_EX = IDEX_rs1;
    forwarded_rs2_EX = IDEX_rs2;

    // Forwarding logic for EX stage operands (EX rd = ID rs1/rs2)
    // rs1 forwarding 
    if (EXMEM_canForward && (EXMEM_rd == IDEX_rs1_addr)) begin
        forwarded_rs1_EX = EXMEM_forwardData;
    end else if (MEMWB_regWrite && (MEMWB_rd != 5'd0) && (MEMWB_rd == IDEX_rs1_addr)) begin
        forwarded_rs1_EX = writeBackData;
    end

    // rs2 forwarding
    if (EXMEM_canForward && (EXMEM_rd == IDEX_rs2_addr)) begin
        forwarded_rs2_EX = EXMEM_forwardData;
    end else if (MEMWB_regWrite && (MEMWB_rd != 5'd0) && (MEMWB_rd == IDEX_rs2_addr)) begin
        forwarded_rs2_EX = writeBackData;
    end
end

endmodule
