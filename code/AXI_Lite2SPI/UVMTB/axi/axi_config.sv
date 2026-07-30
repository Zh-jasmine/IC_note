class axi_config extends uvm_object;

    `uvm_object_utils(axi_config)

    virtual axi_interface vif;

    function new(string name = "axi_config");
        super.new(name);
    endfunction : new

endclass : axi_config
