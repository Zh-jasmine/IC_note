class axi_base_seq extends uvm_sequence #(axi_seq_item);

    `uvm_object_utils(axi_base_seq)

    function new(string name = "axi_base_seq");
        super.new(name);
    endfunction : new

endclass : axi_base_seq


class axi_write_seq extends axi_base_seq;

    `uvm_object_utils(axi_write_seq)

    rand bit [31:0] waddr;
    rand bit [31:0] wdata;
    rand bit [ 3:0] wstrb = 4'hF;
    int unsigned aw_delay = 0;   // AW 通道延迟（ACLK 周期）
    int unsigned w_delay  = 0;   // W  通道延迟（ACLK 周期）
    bit [1:0] bresp_o;

    function new(string name = "axi_write_seq");
        super.new(name);
    endfunction : new

    task body();
        axi_seq_item item = axi_seq_item::type_id::create("item");
        axi_seq_item rsp;

        start_item(item);
        item.addr     = waddr;
        item.wdata    = wdata;
        item.wstrb    = wstrb;
        item.write    = 1;
        item.aw_delay = aw_delay;
        item.w_delay  = w_delay;
        finish_item(item);
        get_response(rsp);
        bresp_o = rsp.bresp;
    endtask : body

endclass : axi_write_seq


class axi_read_seq extends axi_base_seq;

    `uvm_object_utils(axi_read_seq)

    rand bit [31:0] raddr;
    bit [31:0]      rdata_o;

    function new(string name = "axi_read_seq");
        super.new(name);
    endfunction : new

    task body();
        axi_seq_item item = axi_seq_item::type_id::create("item");
        axi_seq_item rsp;

        start_item(item);
        item.addr  = raddr;
        item.write = 0;
        finish_item(item);
        get_response(rsp);
        rdata_o = rsp.rdata;
    endtask : body

endclass : axi_read_seq



// axi_spi_cfg_seq — SPI 寄存器配置 sequence

class axi_spi_cfg_seq extends axi_base_seq;

    `uvm_object_utils(axi_spi_cfg_seq)


    localparam ADDR_START     = 32'h00;
    localparam ADDR_SPI_MODE  = 32'h08;
    localparam ADDR_SCK_SPEED = 32'h0C;
    localparam ADDR_WORD_LEN  = 32'h10;
    localparam ADDR_IFG       = 32'h14;
    localparam ADDR_CS_SCK    = 32'h18;
    localparam ADDR_SCK_CS    = 32'h1C;
    localparam ADDR_MOSI_DATA = 32'h20;


    rand bit [1:0]  spi_mode_i   = 2'b00;
    rand bit [1:0]  sck_speed_i  = 2'b11;
    rand bit [1:0]  word_len_i   = 2'b10;
    rand bit [7:0]  ifg_i        = 8'h4;
    rand bit [7:0]  cs_sck_i     = 8'h4;
    rand bit [7:0]  sck_cs_i     = 8'h4;
    rand bit [31:0] mosi_data_i  = 32'h0;

    bit start_i = 1'b1;
    bit [3:0] wstrb_i = 4'hF;


    constraint c_valid {
        word_len_i  inside {0, 1, 2, 3};
        spi_mode_i  inside {0, 1, 2, 3};
        sck_speed_i inside {0, 1, 2, 3};
    }

    function new(string name = "axi_spi_cfg_seq");
        super.new(name);
    endfunction : new

    task write_reg(bit [31:0] addr, bit [31:0] data);
        axi_seq_item item = axi_seq_item::type_id::create("item");
        axi_seq_item rsp;
        start_item(item);
        item.addr  = addr;
        item.wdata = data;
        item.wstrb = wstrb_i;
        item.write = 1'b1;
        finish_item(item);
        get_response(rsp);
    endtask : write_reg


    task body();

        write_reg(ADDR_SPI_MODE,  {30'h0, spi_mode_i});
        write_reg(ADDR_SCK_SPEED, {30'h0, sck_speed_i});
        write_reg(ADDR_WORD_LEN,  {30'h0, word_len_i});
        write_reg(ADDR_IFG,       {24'h0, ifg_i});
        write_reg(ADDR_CS_SCK,    {24'h0, cs_sck_i});
        write_reg(ADDR_SCK_CS,    {24'h0, sck_cs_i});

        if (start_i) begin
            write_reg(ADDR_MOSI_DATA, mosi_data_i);
            write_reg(ADDR_START, 32'h1);
        end
    endtask : body

endclass : axi_spi_cfg_seq
