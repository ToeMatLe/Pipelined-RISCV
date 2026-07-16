module InstructionMem (
    input logic [31:0] address,
    output logic [31:0] instruction
);
// 64 x 32 memory storage, and array of instructions
logic [31:0] rom_memory [0:63];

// To load instruciton after synthesis, we can use $readmemh to read the instructions from a file and load them into the instruction memory
// program.mem contains the instructions 
// TB are for simulation, not timing analysis
initial begin
    $readmemh("program.mem", rom_memory);
end

// Each instruction occupies 4 bytes, so we can ignore the last 2 bits of the address to index the instruction memory
assign instruction = rom_memory[address [7:2]]; 
endmodule