class eth_back2back_sequence extends eth_sequence;
   `uvm_object_utils(eth_back2back_sequence)
   eth_trans tr;

   function new(string name = "eth_back2back_sequence");
      super.new(name);
   endfunction

   task body();
      repeat(10) begin
         `uvm_do_with(tr, { tr.inject_crc_err == 1'b0;
                            tr.payload.size() inside {[64:256]}; })
      end
   endtask
endclass

class eth_back2back_test extends eth_base_test;
   `uvm_component_utils(eth_back2back_test)
   eth_back2back_sequence b2b_seq;

   function new(string name = "eth_back2back_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      b2b_seq = eth_back2back_sequence::type_id::create("b2b_seq");
   endfunction: build_phase

   virtual task run_phase(uvm_phase phase);
      `uvm_info("eth_back2back_test", "Starting back-to-back frame test", UVM_HIGH)
      phase.raise_objection(this);
      b2b_seq.start(env.m_agent.m_sequencer);
      phase.drop_objection(this);
   endtask: run_phase

   function void end_of_elaboration();
      uvm_top.print_topology();
      uvm_report_info(get_full_name(), "END_OF_ELABORATION", UVM_LOW);
   endfunction

endclass
