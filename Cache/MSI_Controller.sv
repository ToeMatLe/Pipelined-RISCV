`timescale 1ns / 1ps
`include "typedef.svh"

module MSI_Controller (
    input msiState current_state,

    // Local cache access from this CPU.
    input logic read,
    input logic write,

    // External snoop signals from another cache/core.
    input logic bus_read,
    input logic bus_write,

    output msiState next_state,
    output logic issue_bus_rd,
    output logic issue_bus_rdx,
    output logic issue_bus_upgrade,
    output logic issue_bus_wb
);

always_comb begin
    next_state = current_state;
    issue_bus_rd = 1'b0;
    issue_bus_rdx = 1'b0;
    issue_bus_upgrade = 1'b0;
    issue_bus_wb = 1'b0;

    case (current_state)
        MSI_INVALID: begin
            if (read) begin
                next_state = MSI_SHARED;
                issue_bus_rd = 1'b1;
            end else if (write) begin
                next_state = MSI_MODIFIED;
                issue_bus_rdx = 1'b1;
            end
        end

        MSI_SHARED: begin
            if (bus_write) begin
                next_state = MSI_INVALID;
            end else if (write) begin
                next_state = MSI_MODIFIED;
                issue_bus_upgrade = 1'b1;
            end
        end

        MSI_MODIFIED: begin
            if (bus_read) begin
                next_state = MSI_SHARED;
                issue_bus_wb = 1'b1;
            end else if (bus_write) begin
                next_state = MSI_INVALID;
                issue_bus_wb = 1'b1;
            end
        end

        default: begin
            next_state = MSI_INVALID;
        end
    endcase
end

endmodule
