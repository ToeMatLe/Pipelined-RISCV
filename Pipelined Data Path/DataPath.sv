`timescale 1ns / 1ps
`include "typedef.svh"

module DataPath (
    input logic clk,
    input logic reset_n
);

// -----------------------------------------------------------------------------------------------------------------------
// IF stage: PC + Instruction fetch 
// -----------------------------------------------------------------------------------------------------------------------
// IF stage signals
logic [31:0] pcAddress_IF;
logic [31:0] pcAddress_4_IF;
logic [31:0] instruction_IF;

assign pcAddress_4_IF = pcAddress_IF + 32'd4;
// Control coming from hazard unit
logic stall_IF;     // hold PC and IF/ID
logic flush_IFID;   // inject NOP into IF/ID (on redirect)

// Redirect from EX
logic redirect_EX;                  // Control signal to indicate EX stage has a jump/branch 
logic [31:0] redirect_target_EX;    // Target address from EX stage for jump/branch

// EX stage signals for jump/branch decisions
logic jump_taken_EX;
logic [31:0] jump_target_EX;
logic branch_taken_EX;
logic [31:0] branch_target_EX;

assign redirect_EX = jump_taken_EX | branch_taken_EX; //Both shouldnt happen at the same time (CAN DEFINE PRIORITY LATER)
assign flush_IFID = redirect_EX; // On redirect, we need to flush IF/ID to prevent wrong instruction from being decoded

// Program Counter
// We drive jump_enable/branEnable/targets from EX stage.
ProgramCounter programCounter (
    .clk(clk),
    .reset_n(reset_n),
    
    .jump_enable(jump_taken_EX),
    .branEnable(branch_taken_EX),
    .branAddress(branch_target_EX),
    .jump_target_address(jump_target_EX),

    .outputPCAddress(pcAddress_IF),
    .stall(stall_IF),                   // New stall support
);

// Instruction memory 
InstructionMem instructionMem (
    .address(pcAddress_IF),
    .instruction(instruction_IF)
);

// IF/ID pipeline register - holds PC, PC+4, and instruction for the ID stage
// At the end of this stage, the instruction is stored in the IF/ID pipeline register.
logic [31:0] IFID_pcAddress;
logic [31:0] IFID_pcAddress_4;
logic [31:0] IFID_instruction;

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        IFID_pcAddress <= 32'b0;
        IFID_pcAddress_4 <= 32'b0;
        IFID_instruction <= 32'h0000_0013; // NOP = addi x0,x0,0. Never insert garbage instruction on reset. This is for I-type instructions
    end else if (!stall_IF) begin
        IFID_pcAddress <= pcAddress_IF;
        IFID_pcAddress_4 <= pcAddress_4_IF;
        if (flush_IFID)
            IFID_instruction <= 32'h0000_0013; // kill wrong-path instruction
        else
            IFID_instruction <= instruction_IF;
    end
end

// -----------------------------------------------------------------------------------------------------------------------
// ID stage: Instruction decode, register read, immediate generation
// -----------------------------------------------------------------------------------------------------------------------
// Wires to extract fields from instruction
logic [6:0] opcode_ID;
logic [4:0] rd_ID, rs1_ID, rs2_ID;
logic [2:0] funct3_ID;
logic [6:0] funct7_ID;

// Decoding the instruction fields
assign opcode_ID = IFID_instruction[6:0];
assign rd_ID = IFID_instruction[11:7];
assign funct3_ID = IFID_instruction[14:12];
assign rs1_ID = IFID_instruction[19:15];
assign rs2_ID = IFID_instruction[24:20];
assign funct7_ID = IFID_instruction[31:25];

logic [31:0] readData1, readData2; // Data read from registers

// Control signals from the control unit
logic regWrite_ID, memWrite_ID, memRead_ID, aluSrc, branchEnable_ID, jumpEnable_ID;
aluOperations aluOp_ID;

// Immediate Generator for RISC-V formats
// This logic reassembles the scattered immediate bits
always_comb begin
    // Based on the RISC-V reference card formats
    case (opcode)
        I:      sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        LOAD:   sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        JALR:   sign_extended_immediate = {{20{instruction[31]}}, instruction[31:20]};
        STORE:  sign_extended_immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        BRANCH: sign_extended_immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        LUI:    sign_extended_immediate = {instruction[31:12], 12'b0};
        AUIPC:  sign_extended_immediate = {instruction[31:12], 12'b0};
        JAL:    sign_extended_immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        default: sign_extended_immediate = 32'b0;
    endcase
end

// Control Unit 
ControlUnit controlUnit (
    .opcode(opcode_ID),
    .funct3(funct3_ID),
    .funct7(funct7_ID),
    .regWrite(regWrite_ID),
    .memWrite(memWrite_ID),
    .memRead(memRead_ID),
    .aluSrc(aluSrc),
    .branchEnable(branchEnable_ID),
    .jumpEnable(jumpEnable_ID),
    .aluOp(aluOp_ID)
);
// Register file 
RegisterFile registerFile (
    .clk(clk),
    .regWriteEnable(regWrite_ID), // Control signal to enable writing to the register file
    .readReg1(rs1_ID),
    .readReg2(rs2_ID),
    .writeReg(rd_ID),
    .writeData(writeBackData), // Data to write back from the WB stage
    .readData1(readData1),
    .readData2(readData2)
);

// ID/EX pipeline register - holds all the decoded information for the EX stage
logic [31:0] IDEX_pc;
logic [31:0] IDEX_pc4;
logic [31:0] IDEX_rs1;
logic [31:0] IDEX_rs2;
logic [31:0] IDEX_imm;
logic [4:0]  IDEX_rd;
logic IDEX_regWrite;
logic IDEX_memWrite;
logic IDEX_aluSrc;
logic IDEX_isBranch;
logic IDEX_isJump;
aluOperations IDEX_aluOp;

always_ff @(posedge clk or negedge reset_n) begin 
    if (!reset_n) begin

    end else begin 

    end

end
// ----------------------------------------
// EX stage: ALU operations, branch decisions
// ----------------------------------------
// ALU inputs


endmodule