`timescale 1ns / 1ps
`include "typedef.svh"

/*
The cache sits between the pipeline’s MEM stage and DataMem. 
Its job is to retain up to 16 recently accessed 32-bit words
so a load can potentially be answered from the cache instead of backing memory
*/
module L1DataCache #(
    parameter int CACHE_LINES = 16,

    // DataMem implements 1024 words = 4096 bytes, so only address[11:0] identifies unique storage
    // With 16 lines this makes the cache tag 6 bits
    parameter int ADDR_WIDTH = 12,

    // The present CPU is single-core. Keep the MSI implementation available,
    // but remove it from the synthesized lookup path unless explicitly enabled.
    parameter bit ENABLE_MSI = 1'b0
) (
    input logic clk,
    input logic reset_n,

    // Registered CPU request channel. A request is accepted when both req_valid and req_ready are high on a rising clock edge
    input logic req_valid,    //Valid memory operation
    output logic req_ready,   //Ready to accept
    input logic req_write,
    input logic [31:0] req_address,
    input logic [31:0] req_wdata,

    // Registered CPU response channel. The response remains valid until the CPU accepts it with resp_ready
    output logic resp_valid,
    input logic resp_ready,
    output logic [31:0] resp_rdata,

    // Future snoop inputs. The single-core datapath ties these low
    input logic bus_read,
    input logic bus_write,

    // Optional MSI bus interface.
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
// Registered request/response control
// ---------------------------------------------------------------------------------------------------------------------
typedef enum logic [1:0] {
    CACHE_IDLE,
    CACHE_LOOKUP,
    CACHE_RESPONSE
} cacheControlState;
cacheControlState control_state;

logic req_write_q;
logic [31:0] req_address_q;
logic [31:0] req_wdata_q;
logic [31:0] resp_rdata_q;

assign req_ready = (control_state == CACHE_IDLE);
assign resp_valid = (control_state == CACHE_RESPONSE);
assign resp_rdata = resp_rdata_q;

// ---------------------------------------------------------------------------------------------------------------------
// Address breakdown
// ---------------------------------------------------------------------------------------------------------------------
// Direct-mapped, one 32-bit word per line.
// With ADDR_WIDTH=12 and CACHE_LINES=16:
//   address[1:0]  = byte offset
//   address[5:2]  = 4-bit cache index
//   address[11:6] = 6-bit cache tag
localparam int INDEX_BITS = $clog2(CACHE_LINES); //4
localparam int TAG_BITS = ADDR_WIDTH - 2 - INDEX_BITS; //6

logic [INDEX_BITS-1:0] index;
logic [TAG_BITS-1:0] tag;

assign index = req_address_q[2 + INDEX_BITS - 1:2];
assign tag = req_address_q[ADDR_WIDTH - 1:2 + INDEX_BITS];

// ---------------------------------------------------------------------------------------------------------------------
// Cache storage and registered-request lookup
// ---------------------------------------------------------------------------------------------------------------------
logic [31:0] cache_data [CACHE_LINES-1:0];
logic [TAG_BITS-1:0] cache_tag [CACHE_LINES-1:0];
logic cache_valid [CACHE_LINES-1:0];        // Is Cache line valid? (array of 1-bit flags)
msiState cache_state [CACHE_LINES-1:0];     // Is Cache line in Modified, Shared, or Invalid state?

logic line_valid;
logic tag_match;
logic line_available;
logic evict_modified_line;

assign line_valid = cache_valid[index];
assign tag_match = line_valid && (cache_tag[index] == tag);

// In single-core mode the valid/tag check is the complete hit decision.
// MSI state is only added to the lookup when coherence is explicitly enabled.
assign line_available = tag_match && (!ENABLE_MSI || (cache_state[index] != MSI_INVALID));

assign evict_modified_line = ENABLE_MSI &&
                             (control_state == CACHE_LOOKUP) &&
                             !line_available && line_valid &&
                             (cache_state[index] == MSI_MODIFIED);

// ---------------------------------------------------------------------------------------------------------------------
// Optional MSI state control
// ---------------------------------------------------------------------------------------------------------------------
msiState current_msi_state;
msiState next_msi_state;
logic msi_issue_bus_wb;

generate
    if (ENABLE_MSI) begin : gen_msi
        assign current_msi_state = line_available ? cache_state[index] : MSI_INVALID;
        assign issue_bus_wb = msi_issue_bus_wb || evict_modified_line;

        MSI_Controller msiController (
            .current_state(current_msi_state),
            .read((control_state == CACHE_LOOKUP) && !req_write_q),
            .write((control_state == CACHE_LOOKUP) && req_write_q),
            .bus_read(bus_read),
            .bus_write(bus_write),
            .next_state(next_msi_state),
            .issue_bus_rd(issue_bus_rd),
            .issue_bus_rdx(issue_bus_rdx),
            .issue_bus_upgrade(issue_bus_upgrade),
            .issue_bus_wb(msi_issue_bus_wb)
        );
    end else begin : gen_single_core
        // No coherence traffic or MSI comparison is synthesized in this mode.
        assign current_msi_state = MSI_INVALID;
        assign next_msi_state = req_write_q ? MSI_MODIFIED : MSI_SHARED;
        assign msi_issue_bus_wb = 1'b0;
        assign issue_bus_rd = 1'b0;
        assign issue_bus_rdx = 1'b0;
        assign issue_bus_upgrade = 1'b0;
        assign issue_bus_wb = 1'b0;
    end
endgenerate

// ---------------------------------------------------------------------------------------------------------------------
// Backing memory interface
// ---------------------------------------------------------------------------------------------------------------------
// Stores are write-through. The write pulse occurs only during the registered
// lookup cycle, so a stalled EX/MEM request cannot write DataMem repeatedly.
assign backing_memWrite = (control_state == CACHE_LOOKUP) && req_write_q;
assign backing_address = req_address_q;
assign backing_wdata = req_wdata_q;

// ---------------------------------------------------------------------------------------------------------------------
// Cache transaction state and line updates
// ---------------------------------------------------------------------------------------------------------------------
integer i;

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        control_state <= CACHE_IDLE;
        req_write_q <= 1'b0;
        req_address_q <= 32'b0;
        req_wdata_q <= 32'b0;
        resp_rdata_q <= 32'b0;

        for (i = 0; i < CACHE_LINES; i++) begin
            cache_data[i] <= 32'b0;
            cache_tag[i] <= '0;
            cache_valid[i] <= 1'b0;
            cache_state[i] <= MSI_INVALID;
        end
    end else begin
        case (control_state)
            CACHE_IDLE: begin
                if (req_valid && req_ready) begin
                    req_write_q <= req_write;
                    req_address_q <= req_address;
                    req_wdata_q <= req_wdata;
                    control_state <= CACHE_LOOKUP;
                end
            end

            CACHE_LOOKUP: begin
                // Register the response so neither tag comparison nor MSI
                // state feeds the pipeline clock-enable path combinationally.
                if (req_write_q) begin
                    resp_rdata_q <= 32'b0; // Write response is not used by the CPU
                end else if (line_available) begin
                    resp_rdata_q <= cache_data[index];
                end else begin
                    resp_rdata_q <= backing_rdata;
                end

                if (!line_available) begin
                    // Write-allocate stores and load misses both install a line.
                    cache_tag[index] <= tag;
                    cache_valid[index] <= 1'b1;
                    cache_state[index] <= next_msi_state;
                    cache_data[index] <= req_write_q ? req_wdata_q : backing_rdata;
                end else if (req_write_q) begin
                    // Write-through store hit: update the cached copy as well.
                    cache_state[index] <= next_msi_state;
                    cache_data[index] <= req_wdata_q;
                end

                control_state <= CACHE_RESPONSE;
            end

            CACHE_RESPONSE: begin
                if (resp_ready) control_state <= CACHE_IDLE;
            end

            default: begin
                control_state <= CACHE_IDLE;
            end
        endcase
    end
end

endmodule
