module d_Flop(df_if vif);
  always @(posedge vif.clk)
   begin
  if(vif.rst==1'b1) vif.dout<=1'b0;
  else vif.dout<=vif.din;
  end
 
endmodule


interface df_if;
 //////contron signals
logic clk;
logic rst;
/////input and output signals
logic din;
logic dout;

endinterface
