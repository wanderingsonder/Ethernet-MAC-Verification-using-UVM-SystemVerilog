class eth_coverage extends uvm_component;

   `uvm_component_utils(eth_coverage)

   eth_trans cov_tr;

   covergroup eth_cg;
      cp_payload_size: coverpoint cov_tr.payload.size() {
         bins min_frame   = {[46:63]};
         bins small_frame = {[64:255]};
         bins mid_frame   = {[256:1023]};
         bins large_frame = {[1024:1499]};
         bins max_frame   = {1500};
      }
      cp_crc_err: coverpoint cov_tr.inject_crc_err {
         bins no_err  = {0};
         bins crc_err = {1};
      }
      cp_eth_type: coverpoint cov_tr.eth_type {
         bins ipv4   = {16'h0800};
         bins ipv6   = {16'h86DD};
         bins arp    = {16'h0806};
         bins vlan   = {16'h8100};
         bins others = default;
      }
      cx_size_err: cross cp_payload_size, cp_crc_err;
   endgroup

   function new(string name = "eth_coverage", uvm_component parent = null);
      super.new(name, parent);
      eth_cg = new();
      eth_cg.start();   // ← FIX: Xcelium requires explicit start() to enable sampling
   endfunction

   function void sample(eth_trans tr);
      cov_tr = tr;
      eth_cg.sample();
   endfunction

   function void report_phase(uvm_phase phase);
      $display("[COV] Functional Coverage = %0.2f%%", eth_cg.get_coverage());
   endfunction

endclass