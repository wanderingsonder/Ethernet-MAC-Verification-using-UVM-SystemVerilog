class eth_predictor extends uvm_component;

   `uvm_component_utils(eth_predictor)

   uvm_tlm_analysis_fifo #(eth_trans) mon_pre;
   uvm_analysis_port     #(eth_trans) pre_sco;

   eth_trans mon_tr;
   eth_trans pred_tr;

   function new(string name = "eth_predictor", uvm_component parent = null);
      super.new(name, parent);
      mon_pre = new("mon_pre", this);
      pre_sco = new("pre_sco", this);
   endfunction

   virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      forever begin
         predict();
      end
   endtask

   task predict();
      mon_pre.get(mon_tr);
      pred_tr = eth_trans::type_id::create("pred_tr");

      pred_tr.dst_addr = mon_tr.dst_addr;
      pred_tr.src_addr = mon_tr.src_addr;
      pred_tr.eth_type = mon_tr.eth_type;
      pred_tr.payload  = mon_tr.payload;
      pred_tr.rx_er    = mon_tr.rx_er;
      pred_tr.crc      = compute_crc32(pred_tr);

      pred_tr.display("PRE");
      pre_sco.write(pred_tr);
   endtask

   function bit [31:0] compute_crc32(eth_trans tr);
      bit [31:0] crc = 32'hFFFFFFFF;
      byte unsigned data_bytes[];
      int total;

      total = 6 + 6 + 2 + tr.payload.size();
      data_bytes = new[total];

      for(int i = 5; i >= 0; i--) data_bytes[5-i]  = tr.dst_addr[i*8 +: 8];
      for(int i = 5; i >= 0; i--) data_bytes[11-i] = tr.src_addr[i*8 +: 8];
      data_bytes[12] = tr.eth_type[15:8];
      data_bytes[13] = tr.eth_type[7:0];
      for(int i = 0; i < tr.payload.size(); i++) data_bytes[14+i] = tr.payload[i];

      foreach(data_bytes[i]) begin
         crc = crc ^ (32'(data_bytes[i]));
         repeat(8) begin
            if(crc[0]) crc = (crc >> 1) ^ 32'hEDB88320;
            else        crc = crc >> 1;
         end
      end
      return ~crc;
   endfunction

endclass
