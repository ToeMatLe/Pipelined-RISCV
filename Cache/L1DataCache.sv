`timescale 1ns / 1ps
`include "typedef.svh"

module L1DataCache #(
    parameter int CACHE_LINES = 16
) (
    // Clock and reset
    input logic clk,
    input logic reset_n,

    // Request from the CPU MEM stage
    input logic memRead,
    input logic memWrite,
    input logic [31:0] address,
    input logic [31:0] wdata,

    // Response back to the CPU MEM stage
    output logic [31:0] rdata,
    output logic cache_stall,

    // Future snoop inputs. Current single-core datapath ties these low.
    input logic bus_read,
    input logic bus_write,
    
    // MSI bus interface to snoop other caches
    output logic issue_bus_rd,
    output logic issue_bus_rdx,
    output logic issue_bus_upgrade,
    output logic issue_bus_wb,

    // Backing memory interface to DataMem.
    output logic backing_memWrite,
    output logic [31:0] backing_address,
    output logic [31:0] backing_wdata,
    input logic [31:0] backing_rdata
);

// ---------------------------------------------------------------------------------------------------------------------
// Address breakdown
// ---------------------------------------------------------------------------------------------------------------------
// Current cache model:
// - direct-mapped
// - one 32-bit word per cache line
// - byte offset bits [1:0] are ignored because the CPU currently does word accesses
//
// Example with CACHE_LINES = 16:
// address[1:0] = byte offset inside a word (ignore bottom 2 bits)
// address[5:2] = cache index (4 bits for 16 cache lines)
// address[31:6] = tag
localparam int INDEX_BITS = $clog2(CACHE_LINES);
localparam int TAG_BITS = 32 - 2 - INDEX_BITS;

logic [INDEX_BITS-1:0] index;
logic [TAG_BITS-1:0] tag;

assign index = address[2 + INDEX_BITS - 1:2];
assign tag = address[31:2 + INDEX_BITS];

// ---------------------------------------------------------------------------------------------------------------------
// Cache storage
// ---------------------------------------------------------------------------------------------------------------------
logic [31:0] cache_data [CACHE_LINES-1:0];
logic [TAG_BITS-1:0] cache_tag [CACHE_LINES-1:0];
logic cache_valid [CACHE_LINES-1:0];        // Is Cache line valid? (array of 1-bit flags)
msiState cache_state [CACHE_LINES-1:0];     // Is Cache line in Modified, Shared, or Invalid state?

// ---------------------------------------------------------------------------------------------------------------------
// Hit / miss detection
// ---------------------------------------------------------------------------------------------------------------------
logic access;
logic tag_match;
logic line_valid;
logic line_available;
logic cache_hit;
logic evict_modified_line;

assign access = memRead || memWrite; // CPU is trying to access the cache (Load or Store)
assign line_valid = cache_valid[index]; 
assign tag_match = line_valid && (cache_tag[index] == tag);

assign line_available = tag_match && (cache_state[index] != MSI_INVALID);
assign evict_modified_line = access && !line_available && line_valid && (cache_state[index] == MSI_MODIFIED);

assign cache_hit = access && line_available;
assign cache_stall = access && !line_available;

// ---------------------------------------------------------------------------------------------------------------------
// MSI state control
// ---------------------------------------------------------------------------------------------------------------------
msiState current_msi_state;
msiState next_msi_state;
logic msi_issue_bus_wb;

assign current_msi_state = line_available ? cache_state[index] : MSI_INVALID;
assign issue_bus_wb = msi_issue_bus_wb || evict_modified_line;

MSI_Controller msiController (
    .current_state(current_msi_state),
    .read(memRead),
    .write(memWrite),
    .bus_read(bus_read),
    .bus_write(bus_write),
    .next_state(next_msi_state),
    .issue_bus_rd(issue_bus_rd),
    .issue_bus_rdx(issue_bus_rdx),
    .issue_bus_upgrade(issue_bus_upgrade),
    .issue_bus_wb(msi_issue_bus_wb)
);

// ---------------------------------------------------------------------------------------------------------------------
// Backing memory interface
// ---------------------------------------------------------------------------------------------------------------------
// Stores are write-through: the cache and DataMem are both updated.
// Loads on a miss use backing_rdata to fill the cache line.
assign backing_memWrite = memWrite;
assign backing_address = address;
assign backing_wdata = wdata;

// ---------------------------------------------------------------------------------------------------------------------
// CPU read data
// ---------------------------------------------------------------------------------------------------------------------
// Hit: return the cached word.
// Miss: return 0 for this cycle and ask the datapath to stall.
//       The line fills on the clock edge, then the same request hits next cycle.

assign rdata = cache_hit ? cache_data[index] : 32'b0;

// ---------------------------------------------------------------------------------------------------------------------
// Cache line updates
// ---------------------------------------------------------------------------------------------------------------------
integer i;

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        // Reset all cache lines to invalid state on reset edge
        for (i = 0; i < CACHE_LINES; i++) begin
            cache_data[i] <= 32'b0;
            cache_tag[i] <= '0;
            cache_valid[i] <= 1'b0;
            cache_state[i] <= MSI_INVALID;
        end
    end else if (access && !cache_hit) begin
        cache_tag[index] <= tag;
        cache_valid[index] <= 1'b1;
        cache_state[index] <= next_msi_state;

        if (memWrite) begin
            // Store miss: allocate/fill this cache line with the new store data
            // DataMem also gets updated through backing_memWrite
            cache_data[index] <= wdata;
        end else if (memRead) begin
            // Load miss: fill this cache line from DataMem
            cache_data[index] <= backing_rdata;
        end
    end else if (memWrite) begin
        // Store hit: update the cached word
        // DataMem also gets updated through backing_memWrite
        cache_state[index] <= next_msi_state;
        cache_data[index] <= wdata;
    end
end

endmodule
