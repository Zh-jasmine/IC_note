class axi_env extends uvm_env;
    `uvm_component_utils(axi_env)

    axi_master_agent master_agent[AXI_S_COUNT];
    axi_slave_agent  slave_agent[AXI_M_COUNT];
    axi_virtual_sequencer vseqr;
    axi_ref_model rm;
    axi_scoreboard scb;
    axi_coverage cov;

    function new(string name = "axi_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        foreach (master_agent[i]) begin
            master_agent[i] = axi_master_agent::type_id::create($sformatf("master_agent%0d", i), this);
            uvm_config_db#(int)::set(this, $sformatf("master_agent%0d.*", i), "port_index", i);
        end
        foreach (slave_agent[i]) begin
            slave_agent[i] = axi_slave_agent::type_id::create($sformatf("slave_agent%0d", i), this);
            uvm_config_db#(int)::set(this, $sformatf("slave_agent%0d.*", i), "port_index", i);
        end
        vseqr = axi_virtual_sequencer::type_id::create("vseqr", this);
        rm = axi_ref_model::type_id::create("rm");
        scb = axi_scoreboard::type_id::create("scb", this);
        scb.set_ref_model(rm);
        cov = axi_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        foreach (master_agent[i]) begin
            vseqr.master_seqr[i] = master_agent[i].seqr;
            master_agent[i].mon.ap.connect(scb.s_fifo[i].analysis_export);
            master_agent[i].mon.ap.connect(cov.analysis_export);
        end
        foreach (slave_agent[i]) begin
            slave_agent[i].mon.ap.connect(scb.m_fifo[i].analysis_export);
            slave_agent[i].mon.ap.connect(cov.analysis_export);
        end
    endfunction
endclass
