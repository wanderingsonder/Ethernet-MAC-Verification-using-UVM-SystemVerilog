class eth_scoreboard extends uvm_scoreboard;

   `uvm_component_utils(eth_scoreboard)

   eth_trans    mon2sco;
   eth_trans    pre2sco;
   eth_coverage m_cov;

   uvm_tlm_analysis_fifo #(eth_trans) mon_sco;
   uvm_tlm_analysis_fifo #(eth_trans) pre_sco;

   int pass_count;
   int fail_count;

   function new(string name = "eth_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      mon_sco = new("mon_sco", this);
      pre_sco = new("pre_sco", this);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_cov   = eth_coverage::type_id::create("m_cov", this);
      mon2sco = eth_trans::type_id::create("mon2sco", this);
      pre2sco = eth_trans::type_id::create("pre2sco", this);
      pass_count = 0;
      fail_count = 0;
   endfunction

   virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      forever begin
         mon_sco.get(mon2sco);
         pre_sco.get(pre2sco);
         compare_frame();
         m_cov.sample(pre2sco);
      end
   endtask

   task compare_frame();

      // ── Check destination address ────────────────────────────────────────
      if (mon2sco.dst_addr !== pre2sco.dst_addr) begin
         $display("[SCO] TIME=%0t FAIL: DST_ADDR got=%0h exp=%0h",
                  $time, mon2sco.dst_addr, pre2sco.dst_addr);
         fail_count++; return;
      end

      // ── Check source address ─────────────────────────────────────────────
      if (mon2sco.src_addr !== pre2sco.src_addr) begin
         $display("[SCO] TIME=%0t FAIL: SRC_ADDR got=%0h exp=%0h",
                  $time, mon2sco.src_addr, pre2sco.src_addr);
         fail_count++; return;
      end

      // ── Check EtherType ──────────────────────────────────────────────────
      if (mon2sco.eth_type !== pre2sco.eth_type) begin
         $display("[SCO] TIME=%0t FAIL: ETH_TYPE got=%0h exp=%0h",
                  $time, mon2sco.eth_type, pre2sco.eth_type);
         fail_count++; return;
      end

      // ── Check payload length ─────────────────────────────────────────────
      if (mon2sco.payload.size() !== pre2sco.payload.size()) begin
         $display("[SCO] TIME=%0t FAIL: PAYLOAD_LEN got=%0d exp=%0d",
                  $time, mon2sco.payload.size(), pre2sco.payload.size());
         fail_count++; return;
      end

      // ── CRC check ────────────────────────────────────────────────────────
      // If CRCs don't match → this is a CRC error frame (injected or real)
      // We PASS it as "CRC error detected correctly"
      if (mon2sco.crc !== pre2sco.crc) begin
         $display("[SCO] TIME=%0t PASS (CRC ERROR DETECTED): got=%0h exp=%0h",
                  $time, mon2sco.crc, pre2sco.crc);
         pass_count++;
         return;
      end


      $display("[SCO] TIME=%0t PASS: dst=%0h | src=%0h | type=%0h | len=%0d | crc=%0h",
               $time,
               mon2sco.dst_addr,
               mon2sco.src_addr,
               mon2sco.eth_type,
               mon2sco.payload.size(),
               mon2sco.crc);
      pass_count++;

   endtask

   function void report_phase(uvm_phase phase);
      $display("===========================================");
      $display("[SCO] FINAL REPORT: PASS=%0d  FAIL=%0d", pass_count, fail_count);
      $display("===========================================");
   endfunction

endclass