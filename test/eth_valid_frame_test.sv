class eth_valid_frame_sequence extends eth_sequence;
   `uvm_object_utils(eth_valid_frame_sequence)
   eth_trans tr;

   function new(string name = "eth_valid_frame_sequence");
      super.new(name);
   endfunction

   task body();
      #30;
      repeat(5) begin
         `uvm_do_with(tr, { tr.inject_crc_err == 1'b0; })
      end
   endtask
endclass

class eth_valid_frame_test extends eth_base_test;
   `uvm_component_utils(eth_valid_frame_test)
   eth_valid_frame_sequence v_seq;

   function new(string name = "eth_valid_frame_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      v_seq = eth_valid_frame_sequence::type_id::create("v_seq");
   endfunction: build_phase

   virtual task run_phase(uvm_phase phase);
      `uvm_info("eth_valid_frame_test", "Starting valid frame test", UVM_HIGH)
      phase.raise_objection(this);
      v_seq.start(env.m_agent.m_sequencer);
      phase.drop_objection(this);
   endtask: run_phase

   function void end_of_elaboration();
      uvm_top.print_topology();
      uvm_report_info(get_full_name(), "END_OF_ELABORATION", UVM_LOW);
   endfunction

endclass
