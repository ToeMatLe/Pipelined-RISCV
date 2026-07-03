`timescale 1ns / 1ps

`ifndef ALU_IF_SV
`define ALU_IF_SV

interface alu_if(input logic clk);
    logic        valid;
    logic [3:0]  operation;
    logic [31:0] data1;
    logic [31:0] data2;
    logic [31:0] outputData;

    clocking drv_cb @(negedge clk);
        output valid;
        output operation;
        output data1;
        output data2;
        input  outputData;
    endclocking

    clocking mon_cb @(posedge clk);
        input valid;
        input operation;
        input data1;
        input data2;
        input outputData;
    endclocking
endinterface

`endif
