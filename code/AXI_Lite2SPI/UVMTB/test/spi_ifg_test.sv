// spi_ifg_test - VPlan 3.3
//   Sweep IFG register values and check back-to-back SPI frames complete.
`ifndef SPI_IFG_TEST_SV
`define SPI_IFG_TEST_SV

class spi_ifg_test extends test_base;
    `uvm_component_utils(spi_ifg_test)

    function new(string name = "spi_ifg_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic int ifg;
        automatic axi_spi_cfg_seq seq;

        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i)
                0: ifg = 0;
                1: ifg = 4;
                2: ifg = 16;
            endcase

            repeat (2) begin
                seq = axi_spi_cfg_seq::type_id::create("seq");
                seq.ifg_i       = ifg;
                seq.mosi_data_i = 32'hA5;
                seq.start(env.axi_agt.axi_sqr);
                wait_spi_done();
            end

            `uvm_info(get_name(), $sformatf("IFG=%0d transfer pair done", ifg), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass : spi_ifg_test

`endif