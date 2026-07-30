class environment_config extends uvm_object;

    `uvm_object_utils(environment_config)

    axi_config axi_cfg;
    spi_config spi_cfg;

    function new(string name = "environment_config");
        super.new(name);
    endfunction : new

endclass : environment_config
