module InstructionMem (
    input logic [31:0] address,
    output logic [31:0] instruction
);
// 64 x 32 memory storage, and array of instructions
logic [31:0] rom_memory [63:0];

// Each instruction occupies 4 bytes, so we can ignore the last 2 bits of the address to index the instruction memory
assign instruction = rom_memory[address [7:2]]; 
endmodule