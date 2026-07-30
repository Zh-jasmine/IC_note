// spi_miso_all_0_test — VPlan 4.2
//   MISO 全 0（0x00），验证 DUT 采样 + slv_reg9 读回正确

`ifndef SPI_MISO_ALL_0_TEST_SV
`define SPI_MISO_ALL_0_TEST_SV

class spi_miso_all_0_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_all_0_test)
    function new(string name = "spi_miso_all_0_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'h00;
    endfunction
endclass : spi_miso_all_0_test

`endif
