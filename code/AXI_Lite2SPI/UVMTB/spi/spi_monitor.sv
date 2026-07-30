class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    localparam bit [5:0] SPI_MODE_ADDR = 6'h08;
    localparam bit [5:0] WORD_LEN_ADDR = 6'h10;

    spi_config            spi_cfg;
    axi_config            axi_cfg;
    virtual spi_interface vif;
    virtual axi_interface axi_vif;

    uvm_analysis_port #(spi_seq_item) spi_mtr_port;

    bit [31:0] aw_addr_q[$];
    bit [31:0] w_data_q[$];
    bit [ 3:0] w_strb_q[$];
    bit [ 1:0] spi_mode_shadow;
    bit [ 1:0] word_len_shadow;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        spi_mtr_port = new("spi_mtr_port", this);

        if (!uvm_config_db #(spi_config)::get(this, "", "spi_config", spi_cfg))
            `uvm_fatal(get_name(), "spi_config not found in config_db")
        if (!uvm_config_db #(axi_config)::get(this, "", "axi_config", axi_cfg))
            `uvm_fatal(get_name(), "axi_config not found in config_db")

        vif     = spi_cfg.vif;
        axi_vif = axi_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        fork
            sample_axi_config();
            collect_spi();
        join_none
    endtask : run_phase

    task sample_axi_config();
        forever begin
            @(posedge axi_vif.ACLK);
            if (!axi_vif.ARESETN) begin
                flush_axi_shadow();
            end else begin
                if (axi_vif.AWVALID && axi_vif.AWREADY)
                    aw_addr_q.push_back(axi_vif.AWADDR);
                if (axi_vif.WVALID && axi_vif.WREADY) begin
                    w_data_q.push_back(axi_vif.WDATA);
                    w_strb_q.push_back(axi_vif.WSTRB);
                end
                if (axi_vif.BVALID && axi_vif.BREADY)
                    sample_completed_write(axi_vif.BRESP);
            end
        end
    endtask : sample_axi_config

    function void sample_completed_write(bit [1:0] bresp);
        bit [31:0] addr;
        bit [31:0] data;
        bit [ 3:0] strb;

        if ((aw_addr_q.size() == 0) || (w_data_q.size() == 0) || (w_strb_q.size() == 0))
            return;

        addr = aw_addr_q.pop_front();
        data = w_data_q.pop_front();
        strb = w_strb_q.pop_front();

        if (bresp != 2'b00)
            return;

        if ((addr[5:2] == SPI_MODE_ADDR[5:2]) && strb[0])
            spi_mode_shadow = data[1:0];

        if ((addr[5:2] == WORD_LEN_ADDR[5:2]) && strb[0])
            word_len_shadow = data[1:0];
    endfunction : sample_completed_write

    function void flush_axi_shadow();
        aw_addr_q.delete();
        w_data_q.delete();
        w_strb_q.delete();
        spi_mode_shadow = 2'd0;
        word_len_shadow = 2'd0;
    endfunction : flush_axi_shadow

    task collect_spi();
        bit        cpol;
        bit        cpha;
        bit        sample_on_posedge;
        bit [31:0] shift_reg;
        bit [1:0]  spi_mode_cfg;
        bit [1:0]  word_len_cfg;
        int        num_bits;
        spi_seq_item item;

        forever begin
            @(negedge vif.CS);

            spi_mode_cfg = spi_mode_shadow;
            word_len_cfg = word_len_shadow;

            cpol = spi_mode_cfg[1];
            cpha = spi_mode_cfg[0];
            sample_on_posedge = (cpol == cpha);
            shift_reg = 32'd0;

            case (word_len_cfg)
                2'd0:    num_bits = 32;
                2'd1:    num_bits = 16;
                2'd2:    num_bits = 8;
                2'd3:    num_bits = 4;
                default: num_bits = 8;
            endcase

            fork : frame
                begin : do_sample
                    repeat (num_bits) begin
                        if (sample_on_posedge)
                            @(posedge vif.SCLK);
                        else
                            @(negedge vif.SCLK);

                        shift_reg = {shift_reg[30:0], vif.MOSI};
                    end

                    item = spi_seq_item::type_id::create("item");
                    item.spi_data     = shift_reg;
                    item.word_len     = word_len_cfg;
                    item.spi_mode     = spi_mode_cfg;
                    item.capture_time = $realtime;

                    `uvm_info(get_name(), $sformatf("captured: %s", item.convert2string()), UVM_MEDIUM)

                    spi_mtr_port.write(item);
                end
                begin : reset_abort
                    @(negedge axi_vif.ARESETN);
                    `uvm_info(get_name(), "reset mid-frame: discard partial SPI frame", UVM_MEDIUM)
                end
            join_any
            disable frame;
        end
    endtask : collect_spi

endclass : spi_monitor
