`ifndef ALU_SEQ_ITEM_SV
`define ALU_SEQ_ITEM_SV

class alu_seq_item extends uvm_sequence_item;
    rand bit [3:0]  operation;
    rand bit [31:0] data1;
    rand bit [31:0] data2;

    bit [31:0] outputData;

    constraint legal_operation_c {
        operation inside {[4'h0:4'h9]};
    }

    `uvm_object_utils_begin(alu_seq_item)
        `uvm_field_int(operation,  UVM_DEFAULT)
        `uvm_field_int(data1,      UVM_DEFAULT)
        `uvm_field_int(data2,      UVM_DEFAULT)
        `uvm_field_int(outputData, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "alu_seq_item");
        super.new(name);
    endfunction
endclass

`endif
