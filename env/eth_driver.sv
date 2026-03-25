class eth_driver extends uvm_driver #(eth_trans);

   `uvm_component_utils(eth_driver)

   virtual eth_interface vif;
   eth_trans tr;

   localparam byte PREAMBLE_BYTE = 8'h55;
   localparam byte SFD_BYTE      = 8'hD5;
   localparam int  IFG_LEN       = 12;

   function new(string name = "eth_driver", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   function automatic bit [31:0] calc_crc32(byte data[$]);
      bit [31:0] crc = 32'hFFFFFFFF;

      foreach (data[i]) begin
         crc ^= data[i];
         repeat (8) begin
            if (crc[0])
               crc = (crc >> 1) ^ 32'hEDB88320;
            else
               crc = crc >> 1;
         end
      end

      return ~crc;
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db #(virtual eth_interface)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "virtual interface not found")
   endfunction

   virtual task run_phase(uvm_phase phase);
      forever begin
         seq_item_port.get_next_item(tr);
         drive_frame(tr);
         seq_item_port.item_done();
      end
   endtask

   task drive_frame(eth_trans tr);

      byte data_q[$];
      bit [31:0] crc;

      vif.tx_en <= 0;
      vif.tx_er <= 0;
      vif.txd   <= 0;

      repeat(3) @(posedge vif.gtx_clk);

      @(posedge vif.gtx_clk);
      vif.txd   <= PREAMBLE_BYTE;
      vif.tx_en <= 1;

      repeat (6) begin
         @(posedge vif.gtx_clk);
         vif.txd <= PREAMBLE_BYTE;
      end

      @(posedge vif.gtx_clk);
      vif.txd <= SFD_BYTE;

      for(int i = 5; i >= 0; i--) begin
         @(posedge vif.gtx_clk);
         vif.txd <= tr.dst_addr[i*8 +: 8];
         data_q.push_back(tr.dst_addr[i*8 +: 8]);
      end

      for(int i = 5; i >= 0; i--) begin
         @(posedge vif.gtx_clk);
         vif.txd <= tr.src_addr[i*8 +: 8];
         data_q.push_back(tr.src_addr[i*8 +: 8]);
      end

      @(posedge vif.gtx_clk);
      vif.txd <= tr.eth_type[15:8];
      data_q.push_back(tr.eth_type[15:8]);

      @(posedge vif.gtx_clk);
      vif.txd <= tr.eth_type[7:0];
      data_q.push_back(tr.eth_type[7:0]);

      foreach(tr.payload[i]) begin
         @(posedge vif.gtx_clk);
         vif.txd <= tr.payload[i];
         data_q.push_back(tr.payload[i]);
      end

      // padding
      if (data_q.size() < 46) begin
         int pad = 46 - data_q.size();
         repeat(pad) begin
            @(posedge vif.gtx_clk);
            vif.txd <= 8'h00;
            data_q.push_back(8'h00);
         end
      end

      crc = calc_crc32(data_q);

      if (tr.inject_crc_err)
         crc = ~crc;

     
      for (int i = 0; i < 4; i++) begin
         @(posedge vif.gtx_clk);
         vif.txd <= crc[i*8 +: 8];
      end

      @(posedge vif.gtx_clk);
      vif.tx_en <= 0;
      vif.txd   <= 0;

      repeat(IFG_LEN) @(posedge vif.gtx_clk);

   endtask

endclass