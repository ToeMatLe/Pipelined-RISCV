module RegisterFile (
    // 0 and 1 to define it can write
    input logic clk,
    input logic regWrite,

    // Input Read Address
    input logic [4:0] raddress1,
    input logic [4:0] raddress2,
    // Output Read Data
    output logic [31:0] rdata1,
    output logic [31:0] rdata2,
    // Write Address
    input logic [4:0] waddress,
    // Write Data
    input logic [31:0] wdata
);
// Storage for the 32 Registers, all 32-bit sized
logic [31:0] registers [31:0];

// Read Data is Combinational, when read addresses change, assign read datas the value of the register accordingly to the addresses
always_comb begin
    if (raddress1 == 5'd0) begin
        rdata1 = 32'b0;
    end else if (regWrite && (raddress1 == waddress)) begin
        rdata1 = wdata;
    end else begin
        rdata1 = registers[raddress1];
    end

    if (raddress2 == 5'd0) begin
        rdata2 = 32'b0;
    end else if (regWrite && (raddress2 == waddress)) begin
        rdata2 = wdata;
    end else begin
        rdata2 = registers[raddress2];
    end
end

// Write Data is Sequential 
always_ff @(posedge clk) begin
    if (regWrite && waddress != 5'b0) begin 
        // Non-blocking <= is used in sequential logic, all non-blocking operations happen at the clock edge (note uses values in previous clock cycles)
        registers[waddress] <= wdata;
    end
end
endmodule