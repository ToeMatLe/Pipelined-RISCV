`ifndef ALU_SEQUENCE_SV
`define ALU_SEQUENCE_SV

class alu_sequence extends uvm_sequence #(alu_seq_item);
    `uvm_object_utils(alu_sequence)

    function new(string name = "alu_sequence");
        super.new(name);
    endfunction

    task body();
        send_item(4'h0, 32'd10,        32'd5);          // ADD
        send_item(4'h1, 32'd10,        32'd15);         // SUB
        send_item(4'h2, 32'hAAAA_5555, 32'h0F0F_F0F0);  // XOR
        send_item(4'h3, 32'hF0F0_F0F0, 32'h0FF0_00FF);  // OR
        send_item(4'h4, 32'hF0F0_F0F0, 32'h0FF0_00FF);  // AND
        send_item(4'h5, 32'h0000_0001, 32'd3);          // SLL
        send_item(4'h6, 32'h8000_0000, 32'd1);          // SRL
        send_item(4'h7, 32'h8000_0000, 32'd1);          // SRA
        send_item(4'h8, 32'hFFFF_FFFF, 32'd1);          // SLT
        send_item(4'h9, 32'd1,         32'hFFFF_FFFF);  // SLTU

        // RISC-V shifts only use data2[4:0]. These catch full-width shift bugs.
        send_item(4'h5, 32'h0000_0001, 32'd32);
        send_item(4'h6, 32'h8000_0000, 32'd33);
        send_item(4'h7, 32'h8000_0000, 32'd33);

        repeat (100) begin
            alu_seq_item item;

            item = alu_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) begin
                `uvm_fatal("ALU_SEQ", "Failed to randomize ALU sequence item")
            end
            finish_item(item);
        end
    endtask

    task send_item(bit [3:0] op, bit [31:0] lhs, bit [31:0] rhs);
        alu_seq_item item;

        item = alu_seq_item::type_id::create("item");
        start_item(item);
        item.operation = op;
        item.data1     = lhs;
        item.data2     = rhs;
        finish_item(item);
    endtask
endclass

`endif
