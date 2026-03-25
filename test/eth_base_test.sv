class eth_sequence extends uvm_sequence;
   `uvm_object_utils(eth_sequence)
   function new(string name = "eth_sequence");
      super.new(name);
   endfunction
   virtual task body();
   endtask
endclass

class eth_base_test extends uvm_test;
   `uvm_component_utils(eth_base_test)

   eth_env      env;
   eth_sequence m_seq;

   function new(string name = "eth_base_test", uvm_component parent = null);
      super.new(name, parent);
   endfunction: new

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_seq = eth_sequence::type_id::create("m_seq", this);
      env   = eth_env::type_id::create("env", this);
   endfunction

   function void end_of_elaboration();
      uvm_top.print_topology;
      uvm_report_info(get_full_name(), "End_of_elaboration", UVM_LOW);
   endfunction

   virtual task run_phase(uvm_phase phase);
      super.run_phase(phase);
      m_seq.start(env.m_agent.m_sequencer);
   endtask

endclass
