class eth_crc_error_sequence extends eth_sequence;
   `uvm_object_utils(eth_crc_error_sequence)
   eth_trans tr;

   function new(string name = "eth_crc_error_sequence");
      super.new(name);
   endfunction

   task body();
      #30;
      repeat(5) begin
         `uvm_do_with(tr, { tr.inject_crc_err == 1'b1; })
      end
   endtask
endclass

class eth_crc_error_test extends eth_base_test;
   `uvm_component_utils(eth_crc_error_test)
   eth_crc_error_sequence err_seq;

   function new(string name = "eth_crc_error_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      err_seq = eth_crc_error_sequence::type_id::create("err_seq");
   endfunction: build_phase

   virtual task run_phase(uvm_phase phase);
      `uvm_info("eth_crc_error_test", "Starting CRC error injection test", UVM_HIGH)
      phase.raise_objection(this);
      err_seq.start(env.m_agent.m_sequencer);
      phase.drop_objection(this);
   endtask: run_phase

   function void end_of_elaboration();
      uvm_top.print_topology();
      uvm_report_info(get_full_name(), "END_OF_ELABORATION", UVM_LOW);
   endfunction

endclass
