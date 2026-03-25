class eth_rand_frame_sequence extends eth_sequence;
   `uvm_object_utils(eth_rand_frame_sequence)
   eth_trans tr;

   function new(string name = "eth_rand_frame_sequence");
      super.new(name);
   endfunction

   task body();
      #30;
      repeat(20) begin
         `uvm_do_with(tr, { tr.inject_crc_err == 1'b0; })
      end
   endtask
endclass

class eth_rand_test extends eth_base_test;
   `uvm_component_utils(eth_rand_test)
   eth_rand_frame_sequence rand_seq;

   function new(string name = "eth_rand_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      rand_seq = eth_rand_frame_sequence::type_id::create("rand_seq");
   endfunction: build_phase

   virtual task run_phase(uvm_phase phase);
      `uvm_info("eth_rand_test", "Starting constrained-random frame test", UVM_HIGH)
      phase.raise_objection(this);
      rand_seq.start(env.m_agent.m_sequencer);
      phase.drop_objection(this);
   endtask: run_phase

   function void end_of_elaboration();
      uvm_top.print_topology();
      uvm_report_info(get_full_name(), "END_OF_ELABORATION", UVM_LOW);
   endfunction

endclass
