typedef class eth_sequencer;

class eth_env extends uvm_env;

   virtual eth_interface vif;
   eth_agent      m_agent;
   eth_predictor  pre;
   eth_scoreboard sco;

   `uvm_component_utils(eth_env)

   function new(string name = "eth_env", uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_agent = eth_agent::type_id::create("m_agent", this);
      sco     = eth_scoreboard::type_id::create("sco",     this);
      pre     = eth_predictor::type_id::create("pre",      this);

      if(!uvm_config_db #(virtual eth_interface)::get(this, "", "vif", vif))
         `uvm_fatal(get_full_name(), {"virtual interface must be set for env: ", "vif"})
   endfunction: build_phase

   function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      m_agent.m_monitor.mon_ps.connect(pre.mon_pre.analysis_export);
      m_agent.m_monitor.mon_ps.connect(sco.mon_sco.analysis_export);
      pre.pre_sco.connect(sco.pre_sco.analysis_export);
   endfunction: connect_phase

endclass
