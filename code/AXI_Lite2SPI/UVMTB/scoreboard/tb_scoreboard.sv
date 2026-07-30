class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    localparam bit [5:0] WORD_LEN_ADDR = 6'h10;
    localparam bit [5:0] SPI_DATA_ADDR = 6'h20;

    uvm_tlm_analysis_fifo #(axi_seq_item) axi_fifo;
    uvm_tlm_analysis_fifo #(spi_seq_item) spi_fifo;

    bit [31:0] aw_addr_q[$];
    bit [31:0] w_data_q[$];
    bit [ 3:0] w_strb_q[$];
    bit [31:0] ar_addr_q[$];
    bit [31:0] expected_data_q[$];

    axi_config axi_cfg;
    bit [1:0] word_len_shadow;

    int axi_write_count;
    int axi_write_data_count;
    int axi_read_count;
    int match_count;
    int mismatch_count;
    int protocol_error_count;

    function new(string name = "tb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_fifo = new("axi_fifo", this);
        spi_fifo = new("spi_fifo", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg)) begin
            `uvm_fatal(get_name(), "axi_config not found in config_db")
        end
    endfunction : build_phase

    function void handle_axi_item(axi_seq_item item);
        case (item.kind)
            AXI_CH_AW: aw_addr_q.push_back(item.addr);
            AXI_CH_W: begin
                w_data_q.push_back(item.wdata);
                w_strb_q.push_back(item.wstrb);
            end
            AXI_CH_B: handle_write_response(item.bresp);
            AXI_CH_AR: ar_addr_q.push_back(item.addr);
            AXI_CH_R: handle_read_response(item.rdata, item.rresp);
            default: begin
                if (item.write) begin
                    process_write(item.addr, item.wdata, item.wstrb, item.bresp);
                end else begin
                    process_read(item.addr, item.rdata, item.rresp);
                end
            end
        endcase
    endfunction : handle_axi_item

    function void handle_write_response(bit [1:0] bresp);
        bit [31:0] addr;
        bit [31:0] data;
        bit [ 3:0] strb;

        if ((aw_addr_q.size() == 0) || (w_data_q.size() == 0) || (w_strb_q.size() == 0)) begin
            protocol_error_count++;
            `uvm_error("SCB_AXI_ORDER", "B response observed before matching AW/W handshakes")
            return;
        end

        addr = aw_addr_q.pop_front();
        data = w_data_q.pop_front();
        strb = w_strb_q.pop_front();
        process_write(addr, data, strb, bresp);
    endfunction : handle_write_response

    function void handle_read_response(bit [31:0] data, bit [1:0] rresp);
        bit [31:0] addr;

        if (ar_addr_q.size() == 0) begin
            protocol_error_count++;
            `uvm_error("SCB_AXI_ORDER", "R response observed before matching AR handshake")
            return;
        end

        addr = ar_addr_q.pop_front();
        process_read(addr, data, rresp);
    endfunction : handle_read_response

    function void process_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb, bit [1:0] bresp);
        bit [31:0] exp_data;

        axi_write_count++;

        if (bresp != 2'b00) begin
            protocol_error_count++;
            `uvm_error("SCB_AXI_RESP", $sformatf("Write response is not OKAY: addr=0x%0h bresp=%0h", addr, bresp))
            return;
        end

        if (addr[5:2] == WORD_LEN_ADDR[5:2]) begin
            if (strb[0]) word_len_shadow = data[1:0];
        end

        if (addr[5:2] != SPI_DATA_ADDR[5:2])
            return;

        case (word_len_shadow)
            2'd0:    exp_data = data;
            2'd1:    exp_data = {16'd0, data[15:0]};
            2'd2:    exp_data = {24'd0, data[7:0]};
            2'd3:    exp_data = {28'd0, data[3:0]};
            default: exp_data = {24'd0, data[7:0]};
        endcase

        expected_data_q.push_back(exp_data);
        axi_write_data_count++;
    endfunction : process_write

    function void process_read(bit [31:0] addr, bit [31:0] data, bit [1:0] rresp);
        axi_read_count++;

        if (rresp != 2'b00) begin
            protocol_error_count++;
            `uvm_error("SCB_AXI_RESP", $sformatf("Read response is not OKAY: addr=0x%0h rresp=%0h data=0x%0h", addr, rresp, data))
        end
    endfunction : process_read

    function void handle_spi_item(spi_seq_item item);
        bit [31:0] exp_data;

        if (expected_data_q.size() == 0) begin
            `uvm_error("SCB_UNEXP_SPI", $sformatf(
                "Unexpected SPI data (queue empty): spi_data=0x%0h", item.spi_data))
            return;
        end

        exp_data = expected_data_q.pop_front();

        if (exp_data == item.spi_data) begin
            match_count++;
            `uvm_info("SCB_MATCH", $sformatf(
                "PASS: expected 0x%0h == actual 0x%0h (match=%0d)",
                exp_data, item.spi_data, match_count), UVM_MEDIUM)
        end else begin
            mismatch_count++;
            `uvm_error("SCB_MISMATCH", $sformatf(
                "FAIL: expected 0x%0h != actual 0x%0h (mismatch=%0d)",
                exp_data, item.spi_data, mismatch_count))
        end
    endfunction : handle_spi_item

    task run_phase(uvm_phase phase);
        fork
            consume_axi();
            consume_spi();
            reset_watch();
        join_none
    endtask : run_phase

    task consume_axi();
        axi_seq_item item;
        forever begin
            axi_fifo.get(item);
            handle_axi_item(item);
        end
    endtask : consume_axi

    task consume_spi();
        spi_seq_item item;
        forever begin
            spi_fifo.get(item);
            handle_spi_item(item);
        end
    endtask : consume_spi

    task reset_watch();
        forever begin
            @(negedge axi_cfg.vif.ARESETN);
            flush_input_fifos();
            aw_addr_q.delete();
            w_data_q.delete();
            w_strb_q.delete();
            ar_addr_q.delete();
            expected_data_q.delete();
            word_len_shadow = 2'd0;
        end
    endtask : reset_watch

    function void flush_input_fifos();
        axi_seq_item axi_item;
        spi_seq_item spi_item;

        while (axi_fifo.try_get(axi_item)) begin end
        while (spi_fifo.try_get(spi_item)) begin end
    endfunction : flush_input_fifos

    function void report_phase(uvm_phase phase);
        string scb_summary_msg;
        super.report_phase(phase);
        scb_summary_msg = $sformatf(
            "\n  AXI writes          : %0d\n  AXI reads           : %0d\n  AXI spi_data writes : %0d\n  SPI captures        : %0d\n  Matches             : %0d\n  Mismatches          : %0d\n  Protocol errors     : %0d\n  Pending exp data    : %0d\n  Pending AW/W/AR     : %0d/%0d/%0d\n",
            axi_write_count,
            axi_read_count,
            axi_write_data_count,
            match_count + mismatch_count,
            match_count,
            mismatch_count,
            protocol_error_count,
            expected_data_q.size(),
            aw_addr_q.size(),
            w_data_q.size(),
            ar_addr_q.size());
        `uvm_info("SCB_SUMMARY", scb_summary_msg, UVM_LOW)

        if ((mismatch_count == 0) &&
            (protocol_error_count == 0) &&
            (expected_data_q.size() == 0) &&
            (aw_addr_q.size() == 0) &&
            (w_data_q.size() == 0) &&
            (ar_addr_q.size() == 0))
            `uvm_info("SCB_PASS", "*** SCOREBOARD PASSED ***", UVM_LOW)
        else
            `uvm_error("SCB_FAIL", "*** SCOREBOARD FAILED ***")
    endfunction : report_phase

endclass : tb_scoreboard
