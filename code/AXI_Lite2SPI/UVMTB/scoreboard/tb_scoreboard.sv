class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    uvm_tlm_analysis_fifo #(spi_seq_item) expected_spi_fifo;
    uvm_tlm_analysis_fifo #(spi_seq_item) actual_spi_fifo;

    axi_config axi_cfg;

    int match_count;
    int mismatch_count;
    int unexpected_spi_count;

    function new(string name = "tb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        expected_spi_fifo = new("expected_spi_fifo", this);
        actual_spi_fifo = new("actual_spi_fifo", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg)) begin
            `uvm_fatal(get_name(), "axi_config not found in config_db")
        end
    endfunction : build_phase

    function void compare_spi_item(spi_seq_item actual);
        spi_seq_item exp;

        if (!expected_spi_fifo.try_get(exp)) begin
            unexpected_spi_count++;
            `uvm_error("SCB_UNEXP_SPI", $sformatf(
                "Unexpected SPI data (queue empty): spi_data=0x%0h", actual.spi_data))
            return;
        end

        if (exp.spi_data == actual.spi_data) begin
            match_count++;
            `uvm_info("SCB_MATCH", $sformatf(
                "PASS: expected 0x%0h == actual 0x%0h (match=%0d)",
                exp.spi_data, actual.spi_data, match_count), UVM_MEDIUM)
        end else begin
            mismatch_count++;
            `uvm_error("SCB_MISMATCH", $sformatf(
                "FAIL: expected 0x%0h != actual 0x%0h (mismatch=%0d)",
                exp.spi_data, actual.spi_data, mismatch_count))
        end
    endfunction : compare_spi_item

    task run_phase(uvm_phase phase);
        fork
            compare_spi_stream();
            reset_watch();
        join_none
    endtask : run_phase

    task compare_spi_stream();
        spi_seq_item actual;
        forever begin
            actual_spi_fifo.get(actual);
            compare_spi_item(actual);
        end
    endtask : compare_spi_stream

    task reset_watch();
        forever begin
            @(negedge axi_cfg.vif.ARESETN);
            expected_spi_fifo.flush();
            actual_spi_fifo.flush();
        end
    endtask : reset_watch

    function void report_phase(uvm_phase phase);
        string scb_summary_msg;
        super.report_phase(phase);
        scb_summary_msg = $sformatf(
            "\n  SPI captures        : %0d\n  Matches             : %0d\n  Mismatches          : %0d\n  Unexpected SPI      : %0d\n  Pending expected    : %0d\n",
            match_count + mismatch_count,
            match_count,
            mismatch_count,
            unexpected_spi_count,
            expected_spi_fifo.used());
        `uvm_info("SCB_SUMMARY", scb_summary_msg, UVM_LOW)

        if ((mismatch_count == 0) &&
            (unexpected_spi_count == 0) &&
            (expected_spi_fifo.used() == 0))
            `uvm_info("SCB_PASS", "*** SCOREBOARD PASSED ***", UVM_LOW)
        else
            `uvm_error("SCB_FAIL", "*** SCOREBOARD FAILED ***")
    endfunction : report_phase

endclass : tb_scoreboard
