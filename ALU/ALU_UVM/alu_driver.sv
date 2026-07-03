`ifndef ALU_DRIVER_SV
`define ALU_DRIVER_SV

class alu_driver extends uvm_driver #(alu_seq_item);
    `uvm_component_utils(alu_driver)

    virtual alu_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("ALU_DRV", "virtual interface was not set for alu_driver")
        end
    endfunction

    task run_phase(uvm_phase phase);
        alu_seq_item req;

        vif.drv_cb.valid <= 1'b0;
        vif.drv_cb.operation <= 4'h0;
        vif.drv_cb.data1 <= 32'h0;
        vif.drv_cb.data2 <= 32'h0;

        forever begin
            seq_item_port.get_next_item(req);

            @(vif.drv_cb);
            vif.drv_cb.valid <= 1'b1;
            vif.drv_cb.operation <= req.operation;
            vif.drv_cb.data1 <= req.data1;
            vif.drv_cb.data2 <= req.data2;

            @(vif.drv_cb);
            vif.drv_cb.valid <= 1'b0;

            seq_item_port.item_done();
        end
    endtask
endclass

`endif
