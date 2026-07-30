class axi_env_build_test extends uvm_test;
    `uvm_component_utils(axi_env_build_test)

    axi_env env;

    function new(string name = "axi_env_build_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200ns;
        phase.drop_objection(this);
    endtask
endclass
