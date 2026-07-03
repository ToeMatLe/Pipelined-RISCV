`ifndef ALU_MONITOR_SV
`define ALU_MONITOR_SV

class alu_monitor extends uvm_monitor;
    `uvm_component_utils(alu_monitor)

    virtual alu_if vif;
    uvm_analysis_port #(alu_seq_item) analysis_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("ALU_MON", "virtual interface was not set for alu_monitor")
        end
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.valid) begin
                alu_seq_item item;

                item = alu_seq_item::type_id::create("item", this);
                item.operation  = vif.mon_cb.operation;
                item.data1      = vif.mon_cb.data1;
                item.data2      = vif.mon_cb.data2;
                item.outputData = vif.mon_cb.outputData;

                analysis_port.write(item);
            end
        end
    endtask
endclass

`endif
