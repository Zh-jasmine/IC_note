class axi_monitor extends uvm_component;
    `uvm_component_utils(axi_monitor)

    uvm_analysis_port #(axi_item) ap;
    int port_index;
    bit is_m_side;
    axi_s_vif_t s_vif;
    axi_m_vif_t m_vif;

    function new(string name = "axi_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        port_index = 0;
        is_m_side = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(int)::get(this, "", "port_index", port_index));
        void'(uvm_config_db#(bit)::get(this, "", "is_m_side", is_m_side));
        if (is_m_side) begin
            if (!uvm_config_db#(axi_m_vif_t)::get(this, "", "vif", m_vif)) begin
                `uvm_fatal("NOVIF", $sformatf("%s cannot get m_vif", get_full_name()))
            end
        end else begin
            if (!uvm_config_db#(axi_s_vif_t)::get(this, "", "vif", s_vif)) begin
                `uvm_fatal("NOVIF", $sformatf("%s cannot get s_vif", get_full_name()))
            end
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (is_m_side) sample_m_side();
        else sample_s_side();
    endtask

    task sample_s_side();
        wait(s_vif.aresetn === 1'b1);
        forever begin
            @(posedge s_vif.aclk);
            if (s_vif.awvalid && s_vif.awready) publish_aw_s();
            if (s_vif.wvalid && s_vif.wready) publish_w_s();
            if (s_vif.bvalid && s_vif.bready) publish_b_s();
            if (s_vif.arvalid && s_vif.arready) publish_ar_s();
            if (s_vif.rvalid && s_vif.rready) publish_r_s();
        end
    endtask

    task sample_m_side();
        wait(m_vif.aresetn === 1'b1);
        forever begin
            @(posedge m_vif.aclk);
            if (m_vif.awvalid && m_vif.awready) publish_aw_m();
            if (m_vif.wvalid && m_vif.wready) publish_w_m();
            if (m_vif.bvalid && m_vif.bready) publish_b_m();
            if (m_vif.arvalid && m_vif.arready) publish_ar_m();
            if (m_vif.rvalid && m_vif.rready) publish_r_m();
        end
    endtask

    function axi_item base_item(axi_mon_kind_e kind);
        axi_item item = axi_item::type_id::create("item");
        item.kind = kind;
        item.port_index = port_index;
        item.is_m_side = is_m_side;
        return item;
    endfunction

    function void publish_aw_s();
        axi_item item = base_item(AXI_MON_AW);
        item.id = s_vif.awid; item.addr = s_vif.awaddr; item.len = s_vif.awlen;
        item.size = s_vif.awsize; item.burst = s_vif.awburst;
        ap.write(item);
    endfunction

    function void publish_w_s();
        axi_item item = base_item(AXI_MON_W);
        item.beat_data = s_vif.wdata; item.beat_strb = s_vif.wstrb; item.last = s_vif.wlast;
        ap.write(item);
    endfunction

    function void publish_b_s();
        axi_item item = base_item(AXI_MON_B);
        item.id = s_vif.bid; item.resp = s_vif.bresp;
        ap.write(item);
    endfunction

    function void publish_ar_s();
        axi_item item = base_item(AXI_MON_AR);
        item.id = s_vif.arid; item.addr = s_vif.araddr; item.len = s_vif.arlen;
        item.size = s_vif.arsize; item.burst = s_vif.arburst;
        ap.write(item);
    endfunction

    function void publish_r_s();
        axi_item item = base_item(AXI_MON_R);
        item.id = s_vif.rid; item.beat_data = s_vif.rdata; item.resp = s_vif.rresp; item.last = s_vif.rlast;
        ap.write(item);
    endfunction

    function void publish_aw_m();
        axi_item item = base_item(AXI_MON_AW);
        item.id = m_vif.awid; item.addr = m_vif.awaddr; item.len = m_vif.awlen;
        item.size = m_vif.awsize; item.burst = m_vif.awburst;
        ap.write(item);
    endfunction

    function void publish_w_m();
        axi_item item = base_item(AXI_MON_W);
        item.beat_data = m_vif.wdata; item.beat_strb = m_vif.wstrb; item.last = m_vif.wlast;
        ap.write(item);
    endfunction

    function void publish_b_m();
        axi_item item = base_item(AXI_MON_B);
        item.id = m_vif.bid; item.resp = m_vif.bresp;
        ap.write(item);
    endfunction

    function void publish_ar_m();
        axi_item item = base_item(AXI_MON_AR);
        item.id = m_vif.arid; item.addr = m_vif.araddr; item.len = m_vif.arlen;
        item.size = m_vif.arsize; item.burst = m_vif.arburst;
        ap.write(item);
    endfunction

    function void publish_r_m();
        axi_item item = base_item(AXI_MON_R);
        item.id = m_vif.rid; item.beat_data = m_vif.rdata; item.resp = m_vif.rresp; item.last = m_vif.rlast;
        ap.write(item);
    endfunction
endclass
