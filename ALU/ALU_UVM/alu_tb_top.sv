`timescale 1ns / 1ps

`include "typedef.svh"
`include "uvm_macros.svh"

module alu_tb_top;
    import uvm_pkg::*;
    import alu_uvm_pkg::*;

    logic clk = 1'b0;
    alu_if alu_vif(clk);
    aluOperations dut_operation;

    always #5 clk = ~clk;

    assign dut_operation = aluOperations'(alu_vif.operation);

    ALU dut (
        .operation  (dut_operation),
        .data1      (alu_vif.data1),
        .data2      (alu_vif.data2),
        .outputData (alu_vif.outputData)
    );

    initial begin
        alu_vif.valid     = 1'b0;
        alu_vif.operation = 4'h0;
        alu_vif.data1     = 32'h0;
        alu_vif.data2     = 32'h0;
    end

    initial begin
        uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.env.agent.*", "vif", alu_vif);
        run_test("alu_test");
    end
endmodule
