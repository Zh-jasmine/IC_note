// spi_miso_read_test — VPlan 4.1
//   MISO 回读 0x5A，验证 DUT 采样 + slv_reg9 读回正确

`ifndef SPI_MISO_READ_TEST_SV
`define SPI_MISO_READ_TEST_SV

class spi_miso_read_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_read_test)
    function new(string name = "spi_miso_read_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'h5A;
    endfunction
endclass : spi_miso_read_test

`endif
