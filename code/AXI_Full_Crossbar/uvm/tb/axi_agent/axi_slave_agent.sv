class axi_slave_agent extends uvm_agent;
    `uvm_component_utils(axi_slave_agent)

    axi_slave_driver drv;
    axi_monitor mon;
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "axi_slave_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));
        if (is_active == UVM_ACTIVE) begin
            drv = axi_slave_driver::type_id::create("drv", this);
        end
        mon = axi_monitor::type_id::create("mon", this);
        uvm_config_db#(bit)::set(this, "mon", "is_m_side", 1);
    endfunction
endclass
