class axi_monitor extends uvm_monitor;

    `uvm_component_utils(axi_monitor)

    axi_config            con_cfg;
    virtual axi_interface vif;

    uvm_analysis_port#(axi_seq_item) axi_mtr_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        axi_mtr_port = new("axi_mtr_port", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", con_cfg))
            `uvm_fatal(get_name(), {"axi_config must be set for: ", get_full_name()})

        vif = con_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        wait(vif.ARESETN === 1'b1);

        forever begin
            @(posedge vif.ACLK);
            if (vif.ARESETN) begin
                if (vif.AWVALID && vif.AWREADY) publish_aw();
                if (vif.WVALID  && vif.WREADY)  publish_w();
                if (vif.BVALID  && vif.BREADY)  publish_b();
                if (vif.ARVALID && vif.ARREADY) publish_ar();
                if (vif.RVALID  && vif.RREADY)  publish_r();
            end
        end
    endtask : run_phase

    function axi_seq_item base_item(axi_channel_e kind);
        axi_seq_item item;
        item = axi_seq_item::type_id::create("item");
        item.kind = kind;
        return item;
    endfunction : base_item

    function void publish_aw();
        axi_seq_item item;
        item = base_item(AXI_CH_AW);
        item.write = 1'b1;
        item.addr  = vif.AWADDR;
        axi_mtr_port.write(item);
    endfunction : publish_aw

    function void publish_w();
        axi_seq_item item;
        item = base_item(AXI_CH_W);
        item.write = 1'b1;
        item.wdata = vif.WDATA;
        item.wstrb = vif.WSTRB;
        axi_mtr_port.write(item);
    endfunction : publish_w

    function void publish_b();
        axi_seq_item item;
        item = base_item(AXI_CH_B);
        item.write = 1'b1;
        item.bresp = vif.BRESP;
        axi_mtr_port.write(item);
    endfunction : publish_b

    function void publish_ar();
        axi_seq_item item;
        item = base_item(AXI_CH_AR);
        item.write = 1'b0;
        item.addr  = vif.ARADDR;
        axi_mtr_port.write(item);
    endfunction : publish_ar

    function void publish_r();
        axi_seq_item item;
        item = base_item(AXI_CH_R);
        item.write = 1'b0;
        item.rdata = vif.RDATA;
        item.rresp = vif.RRESP;
        axi_mtr_port.write(item);
    endfunction : publish_r

endclass : axi_monitor
