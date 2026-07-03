`ifndef ALU_SCOREBOARD_SV
`define ALU_SCOREBOARD_SV

class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)

    uvm_analysis_imp #(alu_seq_item, alu_scoreboard) analysis_export;
    int unsigned pass_count;
    int unsigned fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
    endfunction

    function void write(alu_seq_item item);
        bit [31:0] expected;

        expected = predict(item.operation, item.data1, item.data2);

        if (item.outputData !== expected) begin
            fail_count++;
            `uvm_error("ALU_SCB", $sformatf(
                "Mismatch op=0x%0h data1=0x%08h data2=0x%08h expected=0x%08h actual=0x%08h",
                item.operation, item.data1, item.data2, expected, item.outputData
            ))
        end else begin
            pass_count++;
            `uvm_info("ALU_SCB", $sformatf(
                "PASS op=0x%0h data1=0x%08h data2=0x%08h output=0x%08h",
                item.operation, item.data1, item.data2, item.outputData
            ), UVM_MEDIUM)
        end
    endfunction

    function bit [31:0] predict(bit [3:0] op, bit [31:0] lhs, bit [31:0] rhs);
        unique case (op)
            4'h0: predict = lhs + rhs;
            4'h1: predict = lhs - rhs;
            4'h2: predict = lhs ^ rhs;
            4'h3: predict = lhs | rhs;
            4'h4: predict = lhs & rhs;
            4'h5: predict = lhs << rhs[4:0];
            4'h6: predict = lhs >> rhs[4:0];
            4'h7: predict = $signed(lhs) >>> rhs[4:0];
            4'h8: predict = ($signed(lhs) < $signed(rhs)) ? 32'd1 : 32'd0;
            4'h9: predict = (lhs < rhs) ? 32'd1 : 32'd0;
            default: predict = 32'h0;
        endcase
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("ALU_SCB", $sformatf(
            "ALU scoreboard complete: %0d passed, %0d failed",
            pass_count, fail_count
        ), UVM_LOW)
    endfunction
endclass

`endif
