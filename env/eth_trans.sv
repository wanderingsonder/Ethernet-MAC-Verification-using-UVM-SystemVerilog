class eth_trans extends uvm_sequence_item;

   rand bit [47:0] dst_addr;
   rand bit [47:0] src_addr;
   rand bit [15:0] eth_type;
   rand byte        payload[];
   rand bit         inject_crc_err;

   bit [31:0] crc;
   bit        rx_er;

   `uvm_object_utils_begin(eth_trans)
      `uvm_field_int(dst_addr,       UVM_ALL_ON)
      `uvm_field_int(src_addr,       UVM_ALL_ON)
      `uvm_field_int(eth_type,       UVM_ALL_ON)
      `uvm_field_array_int(payload,  UVM_ALL_ON)
      `uvm_field_int(crc,            UVM_ALL_ON)
      `uvm_field_int(inject_crc_err, UVM_ALL_ON)
      `uvm_field_int(rx_er,          UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name = "eth_trans");
      super.new(name);
   endfunction

   constraint payload_size_c  { soft payload.size() inside {[46:200]}; }
   constraint no_err_c        { soft inject_crc_err == 1'b0; }
   constraint addr_diff_c     { soft src_addr != dst_addr; }

   function void display(input string tag);
      $display("[%0s] : [%0t] dst_addr: %0h | src_addr: %0h | eth_type: %0h | payload_len: %0d | crc: %0h | crc_err: %0b",
               tag, $time, dst_addr, src_addr, eth_type, payload.size(), crc, inject_crc_err);
   endfunction

endclass