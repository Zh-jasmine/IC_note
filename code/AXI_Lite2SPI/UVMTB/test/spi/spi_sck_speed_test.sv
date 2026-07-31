// spi_sck_speed_test - VPlan 3.4
//   Sweep SCK divider settings and check SPI data transfer still completes.
`ifndef SPI_SCK_SPEED_TEST_SV
`define SPI_SCK_SPEED_TEST_SV

class spi_sck_speed_test extends test_base;
    `uvm_component_utils(spi_sck_speed_test)

    function new(string name = "spi_sck_speed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;

        phase.raise_objection(this);
        #200;

        for (int speed = 0; speed < 4; speed++) begin
            seq = axi_spi_cfg_seq::type_id::create("seq");
            seq.sck_speed_i = speed;
            seq.mosi_data_i = 32'hAA;
            seq.start(env.axi_agt.axi_sqr);
            wait_spi_done();

            `uvm_info(get_name(), $sformatf("SCK speed=%0d transfer done", speed), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass : spi_sck_speed_test

`endif