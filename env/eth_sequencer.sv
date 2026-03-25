class eth_sequencer extends uvm_sequencer #(eth_trans);

   `uvm_component_utils(eth_sequencer)

   function new(string name = "eth_sequencer", uvm_component parent = null);
      super.new(name, parent);
   endfunction: new

endclass
