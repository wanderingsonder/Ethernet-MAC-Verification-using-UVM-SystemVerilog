interface eth_interface;

   logic gtx_clk;
   logic rx_clk;
   logic rst_n;

   logic tx_en;
   logic tx_er;
   logic [7:0] txd;

   logic rx_dv;
   logic rx_er;
   logic [7:0] rxd;

   logic col;
   logic crs;

   
   clocking mo_cb @(posedge gtx_clk);
      input tx_en;
      input tx_er;
      input txd;
      input rx_er;
   endclocking

endinterface