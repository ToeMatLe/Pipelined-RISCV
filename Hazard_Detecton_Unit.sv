module Hazard_Detection_Unit (
    input logic [4:0] rs1_ID,
    input logic [4:0] rs2_ID,
    input logic [4:0] rd_EX,
    input logic MemRead_EX,
    output logic stall
);
// Read after write hazard detection 
// - Using EX stage RD and ID stage RS1/RS2: if the instruction in the EX stage is a load instruction
//    -> Stall (Bubble insert) 

assign stall = MemRead_EX && (rd_EX != 5'd0) && ((rd_EX == rs1_ID) || (rd_EX == rs2_ID));

endmodule