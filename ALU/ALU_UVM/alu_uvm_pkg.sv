`timescale 1ns / 1ps

`ifndef ALU_UVM_PKG_SV
`define ALU_UVM_PKG_SV

`include "uvm_macros.svh"

package alu_uvm_pkg;
    import uvm_pkg::*;

    `include "alu_seq_item.sv"
    `include "alu_sequence.sv"
    `include "alu_sequencer.sv"
    `include "alu_driver.sv"
    `include "alu_monitor.sv"
    `include "alu_scoreboard.sv"
    `include "alu_agent.sv"
    `include "alu_env.sv"
    `include "alu_test.sv"
endpackage

`endif
