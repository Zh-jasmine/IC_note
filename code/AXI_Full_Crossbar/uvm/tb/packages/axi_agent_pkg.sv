package axi_agent_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_types_pkg::*;

    `include "axi_sequencer.sv"
    `include "axi_master_driver.sv"
    `include "axi_slave_driver.sv"
    `include "axi_monitor.sv"
    `include "axi_master_agent.sv"
    `include "axi_slave_agent.sv"
endpackage
