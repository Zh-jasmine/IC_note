class axi_driver extends uvm_driver #(axi_seq_item);

    `uvm_component_utils(axi_driver)

    axi_config axi_cfg;
    virtual axi_interface vif;

    mailbox #(axi_seq_item) aw_request_mb;
    mailbox #(axi_seq_item) w_request_mb;
    mailbox #(axi_seq_item) ar_request_mb;
    mailbox #(axi_seq_item) b_response_mb;
    mailbox #(axi_seq_item) r_response_mb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        aw_request_mb = new();
        w_request_mb  = new();
        ar_request_mb = new();
        b_response_mb = new();
        r_response_mb = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg)) begin
            `uvm_fatal(get_name(), {"axi_config must be set by ", get_full_name()})
        end
        vif = axi_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        init_outputs();
        wait(vif.ARESETN === 1'b1);

        fork
            reset_signals();
            dispatch_requests();
            drive_aw_channel();
            drive_w_channel();
            drive_ar_channel();
            collect_b_response();
            collect_r_response();
        join_none
    endtask : run_phase

    task dispatch_requests();
        axi_seq_item req_tr;
        axi_seq_item aw_tr;
        axi_seq_item w_tr;
        axi_seq_item b_tr;
        axi_seq_item ar_tr;
        axi_seq_item r_tr;

        forever begin
            seq_item_port.get_next_item(req_tr);

            if (req_tr.write) begin
                aw_tr = clone_request("aw_req", req_tr, AXI_CH_AW);
                w_tr  = clone_request("w_req",  req_tr, AXI_CH_W);
                b_tr  = clone_request("b_rsp",  req_tr, AXI_CH_B);

                aw_request_mb.put(aw_tr);
                w_request_mb.put(w_tr);
                b_response_mb.put(b_tr);
            end else begin
                ar_tr = clone_request("ar_req", req_tr, AXI_CH_AR);
                r_tr  = clone_request("r_rsp",  req_tr, AXI_CH_R);

                ar_request_mb.put(ar_tr);
                r_response_mb.put(r_tr);
            end

            seq_item_port.item_done();
        end
    endtask : dispatch_requests

    function axi_seq_item clone_request(string name, axi_seq_item req_tr, axi_channel_e kind);
        axi_seq_item tr;
        tr = axi_seq_item::type_id::create(name);
        tr.copy(req_tr);
        tr.kind = kind;
        tr.set_id_info(req_tr);
        return tr;
    endfunction : clone_request

    task drive_aw_channel();
        axi_seq_item tr;
        bit delay_done;

        forever begin
            aw_request_mb.get(tr);
            wait(vif.ARESETN === 1'b1);
            wait_active_cycles(tr.aw_delay, delay_done);
            if (!delay_done) continue;

            vif.AWADDR  <= tr.addr;
            vif.AWPROT  <= 3'b000;
            vif.AWVALID <= 1'b1;
            do @(posedge vif.ACLK); while ((vif.ARESETN === 1'b1) && !(vif.AWVALID && vif.AWREADY));
            if (vif.ARESETN !== 1'b1) begin
                vif.AWVALID <= 1'b0;
                continue;
            end
            vif.AWVALID <= 1'b0;
        end
    endtask : drive_aw_channel

    task drive_w_channel();
        axi_seq_item tr;
        bit delay_done;

        forever begin
            w_request_mb.get(tr);
            wait(vif.ARESETN === 1'b1);
            wait_active_cycles(tr.w_delay, delay_done);
            if (!delay_done) continue;

            vif.WDATA  <= tr.wdata;
            vif.WSTRB  <= tr.wstrb;
            vif.WVALID <= 1'b1;
            do @(posedge vif.ACLK); while ((vif.ARESETN === 1'b1) && !(vif.WVALID && vif.WREADY));
            if (vif.ARESETN !== 1'b1) begin
                vif.WVALID <= 1'b0;
                continue;
            end
            vif.WVALID <= 1'b0;
        end
    endtask : drive_w_channel

    task drive_ar_channel();
        axi_seq_item tr;

        forever begin
            ar_request_mb.get(tr);
            wait(vif.ARESETN === 1'b1);

            vif.ARADDR  <= tr.addr;
            vif.ARPROT  <= 3'b000;
            vif.ARVALID <= 1'b1;
            do @(posedge vif.ACLK); while ((vif.ARESETN === 1'b1) && !(vif.ARVALID && vif.ARREADY));
            if (vif.ARESETN !== 1'b1) begin
                vif.ARVALID <= 1'b0;
                continue;
            end
            vif.ARVALID <= 1'b0;
        end
    endtask : drive_ar_channel

    task collect_b_response();
        axi_seq_item tr;

        forever begin
            b_response_mb.get(tr);
            do @(posedge vif.ACLK); while ((vif.ARESETN === 1'b1) && !(vif.BVALID && vif.BREADY));
            if (vif.ARESETN !== 1'b1) begin
                tr.bresp = 2'b10;
                seq_item_port.put(tr);
                continue;
            end
            tr.bresp = vif.BRESP;
            seq_item_port.put(tr);
        end
    endtask : collect_b_response

    task collect_r_response();
        axi_seq_item tr;

        forever begin
            r_response_mb.get(tr);
            do @(posedge vif.ACLK); while ((vif.ARESETN === 1'b1) && !(vif.RVALID && vif.RREADY));
            if (vif.ARESETN !== 1'b1) begin
                tr.rresp = 2'b10;
                tr.rdata = '0;
                seq_item_port.put(tr);
                continue;
            end
            tr.rdata = vif.RDATA;
            tr.rresp = vif.RRESP;
            seq_item_port.put(tr);
        end
    endtask : collect_r_response

    task reset_signals();
        forever begin
            @(negedge vif.ARESETN);
            while (vif.ARESETN === 1'b0) begin
                reset_outputs();
                @(posedge vif.ACLK);
            end
            init_outputs();
        end
    endtask : reset_signals

    task wait_active_cycles(int unsigned cycles, output bit completed);
        completed = 1'b1;
        repeat (cycles) begin
            @(posedge vif.ACLK);
            if (vif.ARESETN !== 1'b1) begin
                completed = 1'b0;
                return;
            end
        end
    endtask : wait_active_cycles

    task init_outputs();
        vif.AWADDR  <= '0;
        vif.AWPROT  <= '0;
        vif.AWVALID <= 1'b0;
        vif.WDATA   <= '0;
        vif.WSTRB   <= '0;
        vif.WVALID  <= 1'b0;
        vif.BREADY  <= 1'b1;
        vif.ARADDR  <= '0;
        vif.ARPROT  <= '0;
        vif.ARVALID <= 1'b0;
        vif.RREADY  <= 1'b1;
    endtask : init_outputs

    task reset_outputs();
        vif.AWADDR  <= '0;
        vif.AWPROT  <= '0;
        vif.AWVALID <= 1'b0;
        vif.WDATA   <= '0;
        vif.WSTRB   <= '0;
        vif.WVALID  <= 1'b0;
        vif.BREADY  <= 1'b0;
        vif.ARADDR  <= '0;
        vif.ARPROT  <= '0;
        vif.ARVALID <= 1'b0;
        vif.RREADY  <= 1'b0;
    endtask : reset_outputs

endclass : axi_driver
