

class transaction ;
 rand bit din;
  bit dout;

  function transaction copy();   //created for sending deep copy of the object 
    copy=new();
    copy.din=this.din;
    copy.dout =this.dout;
  endfunction

function void display(input string tag) ;
    $display("[%0s]: DIN:%0b DOUT:%0b",tag,din,dout);
endfunction

endclass


/////////////////////////////////////////////////////////////////////////////

class generator;
transaction tr;
mailbox #(transaction) mbx; ///mailbox between generator and driver.
mailbox #(transaction) mbxref;///mailbox between generator and scoreboard.

event sconext;  /// event for scoreboard event completion
event done; ////event will be triggered when required number of stimuli is generated

int count;

function new (mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
this.mbx=mbx;
this.mbxref=mbxref;
tr=new();
endfunction

//////// Randomization of data 
task run();
repeat(count) begin
  assert(tr.randomize) else  $display("RANDOMIZATION FAILED");
mbx.put(tr.copy);
mbxref.put(tr.copy);
tr.display("GEN");
@(sconext);
end
  ->done;
endtask



endclass

/////////////////////////////////////////////////////////////////////////////

class driver;

transaction tr;
  mailbox #(transaction) mbx;
virtual df_if vif;  /// interface decclartion

  function new(mailbox #(transaction) mbx);   ///synchronization of mailbox 
this.mbx=mbx;
tr=new();
endfunction

task reset();    ////reset is done
vif.rst<=1'b1;
repeat(5) @(posedge vif.clk)
vif.rst<=1'b0;
 @(posedge vif.clk)
$display("[DRV]:RESET DONE");
endtask

task run () ;
forever begin
   mbx.get(tr);
   vif.din<=tr.din; 
   @(posedge vif.clk);
   tr.display("DRV");
   vif.din<=1'b0; ///// reset din
   @(posedge vif.clk);
end

endtask


endclass

/////////////////////////////////////////////////////////////////////////////

class moniter ;
transaction tr;
  mailbox #(transaction) mbx;
virtual df_if vif;

  function new(mailbox #(transaction) mbx) ;  ///synchronization of mailbox 
this.mbx=mbx;
endfunction

task run() ;
tr=new();
forever begin
    repeat(2) @(posedge vif.clk);
     tr.dout=vif.dout;
     mbx.put(tr);
  tr.display("MON");
end
endtask
endclass


/////////////////////////////////////////////////////////////////////////////

class scoreboard ;
transaction tr;
transaction tr_ref;

  mailbox #(transaction) mbx;  ///from moniter
  mailbox #(transaction) mbxref;//// form GEN

event sconext;

  function new(mailbox #(transaction) mbx,mailbox #(transaction) mbxref);
   this.mbx=mbx;
   this.mbxref=mbxref;
   tr=new();
   tr_ref=new();
endfunction
 
 task run();
  forever begin
    mbx.get(tr);
    mbxref.get(tr_ref);
    tr.display("SCO");
    tr_ref.display("REF");

    if(tr.dout==tr_ref.din) $display("DATA MATCHED");
    else $display("DATA MISMATCHED");


  $display("-----------------------------");
  ->sconext;

  end
 endtask



endclass




/////////////////////////////////////////////////////////////////////////////

class environment ;

generator gen;
driver drv;
virtual df_if vif;
moniter mon;
scoreboard sco;

  mailbox#(transaction) mbx_g2d;
  mailbox#(transaction) mbx_g2s;
  mailbox#(transaction) mbx_m2s;

event next;

  function new(virtual df_if vif);
  
mbx_g2d=new();
mbx_g2s=new();

gen=new(mbx_g2d,mbx_g2s);
drv=new(mbx_g2d);

mbx_m2s=new();
mon=new(mbx_m2s);
sco=new(mbx_m2s,mbx_g2s);

this.vif=vif;
drv.vif=this.vif;
mon.vif=this.vif;

gen.sconext=next;
sco.sconext=next;
endfunction

task pre_test();
drv.reset();
endtask


task test();
fork
gen.run();
drv.run();
mon.run();
sco.run();
join_any

endtask

task post_test();
wait(gen.done.triggered) $finish();
endtask

task run();
pre_test();
test();
post_test();
endtask

endclass




module tb;
  df_if vif(); // Create DUT interface
 
  d_Flop dut (vif); 
  
  initial begin
    vif.clk <= 0; 
  end
  
  always #10 vif.clk <= ~vif.clk; 
  
  environment env; 
 
  initial begin
    env = new(vif); 
    env.gen.count = 30; 
    env.run(); 
  end
  
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars; 
  end
endmodule