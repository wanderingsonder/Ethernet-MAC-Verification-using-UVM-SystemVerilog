class eth_monitor extends uvm_monitor;

   `uvm_component_utils(eth_monitor)

   virtual eth_interface vif;
   uvm_analysis_port #(eth_trans) mon_ps;
   eth_trans tr;

   localparam logic [7:0] SFD_BYTE = 8'hD5;

   function new(string name = "eth_monitor", uvm_component parent = null);
      super.new(name, parent);
      mon_ps = new("mon_ps", this);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tr = eth_trans::type_id::create("tr");
      if(!uvm_config_db #(virtual eth_interface)::get(this, "", "vif", vif))
         `uvm_fatal("NOVIF", "virtual interface not found for eth_monitor")
   endfunction

   virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      forever begin
         capture_frame();
      end
   endtask

   task capture_frame();
      byte unsigned raw_bytes[$];
      byte unsigned b;
      bit in_preamble;

      @(vif.mo_cb iff (vif.mo_cb.tx_en == 1'b1));

      in_preamble = 1;

      while(vif.mo_cb.tx_en) begin
         b = vif.mo_cb.txd;
         if(in_preamble) begin
            if(b == SFD_BYTE) in_preamble = 0;
         end else begin
            raw_bytes.push_back(b);
         end
         @(vif.mo_cb);
      end

      if(raw_bytes.size() < 18) begin
         `uvm_error("MON", "Captured frame too short — discarding")
         return;
      end

      tr = eth_trans::type_id::create("tr");

      tr.dst_addr = 0;
      for(int i = 0; i < 6; i++) tr.dst_addr = (tr.dst_addr << 8) | raw_bytes[i];

      tr.src_addr = 0;
      for(int i = 6; i < 12; i++) tr.src_addr = (tr.src_addr << 8) | raw_bytes[i];

      tr.eth_type = {raw_bytes[12], raw_bytes[13]};

      tr.payload = new[raw_bytes.size() - 18];
      for(int i = 0; i < tr.payload.size(); i++) tr.payload[i] = raw_bytes[14 + i];

      tr.crc = 0;
      for(int i = 3; i >= 0; i--) tr.crc = (tr.crc << 8) | raw_bytes[raw_bytes.size() - 4 + i];

      tr.rx_er = vif.mo_cb.rx_er;

      tr.display("MON");
      mon_ps.write(tr);
   endtask

endclass
