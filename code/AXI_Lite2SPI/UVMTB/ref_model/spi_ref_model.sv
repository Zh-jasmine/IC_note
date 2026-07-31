class spi_ref_model extends uvm_component;

    `uvm_component_utils(spi_ref_model)

    localparam bit [5:0] START_ADDR     = 6'h00;
    localparam bit [5:0] WORD_LEN_ADDR  = 6'h10;
    localparam bit [5:0] MOSI_DATA_ADDR = 6'h20;

    uvm_tlm_analysis_fifo #(axi_seq_item) axi_fifo;
    uvm_analysis_port #(spi_seq_item) expected_spi_item;

    axi_config axi_cfg;

    bit [31:0] aw_addr_q[$];
    bit [31:0] w_data_q[$];
    bit [ 3:0] w_strb_q[$];
    bit [31:0] ar_addr_q[$];
    bit [ 1:0] word_len_shadow;
    bit [31:0] mosi_data_shadow;

    int axi_write_count;
    int expected_spi_count;
    int axi_read_count;
    int protocol_error_count;

    function new(string name = "spi_ref_model", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        axi_fifo = new("axi_fifo", this);
        expected_spi_item = new("expected_spi_item", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg))
            `uvm_fatal(get_name(), "axi_config not found in config_db")
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        fork
            consume_axi();
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
                if (item.write)
                    process_write(item.addr, item.wdata, item.wstrb, item.bresp);
                else
                    process_read(item.addr, item.rdata, item.rresp);
            end
        endcase
    endfunction : handle_axi_item

    function void handle_write_response(bit [1:0] bresp);
        bit [31:0] addr;
        bit [31:0] data;
        bit [ 3:0] strb;

        if ((aw_addr_q.size() == 0) || (w_data_q.size() == 0) || (w_strb_q.size() == 0)) begin
            protocol_error_count++;
            `uvm_error("RM_AXI_ORDER", "B response observed before matching AW/W handshakes")
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
            `uvm_error("RM_AXI_ORDER", "R response observed before matching AR handshake")
            return;
        end

        addr = ar_addr_q.pop_front();
        process_read(addr, data, rresp);
    endfunction : handle_read_response

    function void process_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb, bit [1:0] bresp);
        spi_seq_item exp;

        axi_write_count++;

        if (bresp != 2'b00) begin
            protocol_error_count++;
            `uvm_error("RM_AXI_RESP", $sformatf("Write response is not OKAY: addr=0x%0h bresp=%0h", addr, bresp))
            return;
        end

        if (addr[5:2] == WORD_LEN_ADDR[5:2]) begin
            if (strb[0])
                word_len_shadow = data[1:0];
            return;
        end

        if (addr[5:2] == MOSI_DATA_ADDR[5:2]) begin
            if (strb[0]) mosi_data_shadow[ 7: 0] = data[ 7: 0];
            if (strb[1]) mosi_data_shadow[15: 8] = data[15: 8];
            if (strb[2]) mosi_data_shadow[23:16] = data[23:16];
            if (strb[3]) mosi_data_shadow[31:24] = data[31:24];
            return;
        end

        if ((addr[5:2] != START_ADDR[5:2]) || !strb[0] || !data[0])
            return;

        exp = spi_seq_item::type_id::create("exp");
        exp.word_len = word_len_shadow;
        exp.capture_time = $realtime;

        case (word_len_shadow)
            2'd0:    exp.spi_data = mosi_data_shadow;
            2'd1:    exp.spi_data = {16'd0, mosi_data_shadow[15:0]};
            2'd2:    exp.spi_data = {24'd0, mosi_data_shadow[7:0]};
            2'd3:    exp.spi_data = {28'd0, mosi_data_shadow[3:0]};
            default: exp.spi_data = {24'd0, mosi_data_shadow[7:0]};
        endcase

        expected_spi_item.write(exp);
        expected_spi_count++;

        `uvm_info(get_name(), $sformatf("expected: %s", exp.convert2string()), UVM_MEDIUM)
    endfunction : process_write

    function void process_read(bit [31:0] addr, bit [31:0] data, bit [1:0] rresp);
        axi_read_count++;

        if (rresp != 2'b00) begin
            protocol_error_count++;
            `uvm_error("RM_AXI_RESP", $sformatf("Read response is not OKAY: addr=0x%0h rresp=%0h data=0x%0h", addr, rresp, data))
        end
    endfunction : process_read

    task reset_watch();
        forever begin
            @(negedge axi_cfg.vif.ARESETN);
            axi_fifo.flush();
            aw_addr_q.delete();
            w_data_q.delete();
            w_strb_q.delete();
            ar_addr_q.delete();
            word_len_shadow = 2'd0;
            mosi_data_shadow = 32'd0;
        end
    endtask : reset_watch

    function void report_phase(uvm_phase phase);
        string rm_summary_msg;
        super.report_phase(phase);

        rm_summary_msg = $sformatf(
            "\n  AXI writes          : %0d\n  AXI reads           : %0d\n  Expected SPI items  : %0d\n  Protocol errors     : %0d\n  Pending AW/W/AR     : %0d/%0d/%0d\n",
            axi_write_count,
            axi_read_count,
            expected_spi_count,
            protocol_error_count,
            aw_addr_q.size(),
            w_data_q.size(),
            ar_addr_q.size());
        `uvm_info("RM_SUMMARY", rm_summary_msg, UVM_LOW)

        if ((protocol_error_count != 0) ||
            (aw_addr_q.size() != 0) ||
            (w_data_q.size() != 0) ||
            (ar_addr_q.size() != 0))
            `uvm_error("RM_FAIL", "*** REFERENCE MODEL FAILED ***")
    endfunction : report_phase

endclass : spi_ref_model
