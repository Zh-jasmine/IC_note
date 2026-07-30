class spi_seq_item extends uvm_sequence_item;

    `uvm_object_utils(spi_seq_item)

    bit [31:0]   spi_data;          // 这一笔 SPI 传输的数据（最多32-bit）
    bit [1:0]    word_len;          // 0=32b, 1=16b, 2=8b, 3=4b（与DUT编码一致）
    bit [1:0]    spi_mode;          // SPI 模式（从 config 同步过来）
    realtime     capture_time;      // 数据采集的绝对时间

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction : new

    function string convert2string();
        return $sformatf("spi_data=0x%0h  word_len=%0d  spi_mode=%2b  capture_time=%0t",
                         spi_data, word_len, spi_mode, capture_time);
    endfunction : convert2string

endclass : spi_seq_item
