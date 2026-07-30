class axi_smoke_rw_test extends axi_base_test;
    `uvm_component_utils(axi_smoke_rw_test)

    function new(string name = "axi_smoke_rw_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int)::set(this, "env.master_agent0.*", "awvalid_delay_max", 2);
        uvm_config_db#(int)::set(this, "env.master_agent0.*", "wvalid_delay_max", 2);
        uvm_config_db#(int)::set(this, "env.master_agent0.*", "arvalid_delay_max", 2);
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi_smoke_rw_seq seq;

        phase.raise_objection(this);
        seq = axi_smoke_rw_seq::type_id::create("seq");
        seq.start(env.master_agent[0].seqr);
        #50ns;
        phase.drop_objection(this);
    endtask
endclass
