class axi_master_agent extends uvm_agent;
    `uvm_component_utils(axi_master_agent)

    axi_sequencer seqr;
    axi_master_driver drv;
    axi_monitor mon;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "axi_master_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));
        if (is_active == UVM_ACTIVE) begin
            seqr = axi_sequencer::type_id::create("seqr", this);
            drv = axi_master_driver::type_id::create("drv", this);
        end
        mon = axi_monitor::type_id::create("mon", this);
        uvm_config_db#(bit)::set(this, "mon", "is_m_side", 0);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active == UVM_ACTIVE) drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

