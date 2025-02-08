`include "uvm_macros.svh"
import uvm_pkg::*;

class spi_config extends uvm_object;
    `uvm_object_utils(spi_config)

    function new(string path = "spi_config");
        super.new(path);
    endfunction

    uvm_active_passive_enum is_active = UVM_ACTIVE;

endclass

typedef enum bit [1:0] {readd = 0; writed = 1; rstdut = 2} oper_mode;

class transaction extends uvm_sequence_item;

    randc logic [7:0] addr;
    rand logic [7:0] din;
        logic [7:0] dout;
    rand oper_mode op;
        logic cs;
    rand logic miso;
        logic rst;
        logic ready;
        logic done;
        logic mosi;
        logic err;
    
    constraint addr_c { addr <= 10;}
        `uvm_object_utils_begin(transaction)
            `uvm_field_int (addr,UVM_ALL_ON)
            `uvm_field_int (din,UVM_ALL_ON)
            `uvm_field_int (dout,UVM_ALL_ON)
            `uvm_field_int (ready,UVM_ALL_ON)
            `uvm_field_int (rst,UVM_ALL_ON)
            `uvm_field_int (done,UVM_ALL_ON)
            `uvm_field_int (miso,UVM_ALL_ON)
            `uvm_field_int (mosi,UVM_ALL_ON)
            `uvm_field_int (cs,UVM_ALL_ON)
            `uvm_field_int (err,UVM_ALL_ON)
            `uvm_field_enum(oper_mode, op, UVM_DEFAULT)
        `uvm_object_utils_end

    function new(string path = "transaction");
        super.new(path);
    endfunction
endclass

class write_data extends uvm_sequence#(transaction);
    `uvm_object_utils(write_data)
    
    transaction tr;
   
    function new(string name = "write_data");
      super.new(name);
    endfunction
    
    virtual task body();
      repeat(15)
        begin
          tr = transaction::type_id::create("tr");
          tr.addr_c.constraint_mode(1);
          start_item(tr);
          assert(tr.randomize);
          tr.op = writed;
          finish_item(tr);
        end
    endtask
    
   
  endclass
  //////////////////////////////////////////////////////////
   
   
  class read_data extends uvm_sequence#(transaction);
    `uvm_object_utils(read_data)
    
    transaction tr;
   
    function new(string name = "read_data");
      super.new(name);
    endfunction
    
    virtual task body();
      repeat(15)
        begin
          tr = transaction::type_id::create("tr");
          tr.addr_c.constraint_mode(1);
          start_item(tr);
          assert(tr.randomize);
          tr.op = readd;
          finish_item(tr);
        end
    endtask
    
   
  endclass
  /////////////////////////////////////////////////////////////////////
   
  class reset_dut extends uvm_sequence#(transaction);
    `uvm_object_utils(reset_dut)
    
    transaction tr;
   
    function new(string name = "reset_dut");
      super.new(name);
    endfunction
    
    virtual task body();
      repeat(15)
        begin
          tr = transaction::type_id::create("tr");
          tr.addr_c.constraint_mode(1);
          start_item(tr);
          assert(tr.randomize);
          tr.op = rstdut;
          finish_item(tr);
        end
    endtask
    
   
  endclass
  
class writeb_readb extends uvm_sequence#(transaction);
    `uvm_object_utils(writeb_readb)

    transaction tr;

    function new(string path = "writeb_readb");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            start_item(tr);
            assert(tr.randomize);
            tr.op = writed;
            finish_item(tr);
        end

        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            start_item(tr);
            assert(tr.randomize);
            tr.op = readd;
            finish_item(tr);
        end
    endtask
endclass

class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    virtual spi_i vif;
    transaction tr;

    //logic [15:0] data; //din, addr
    logic [7:0] datard;
    logic [7:0] din;
    logic [7:0] addr;

    function new(string path = "driver", uvm_component parent = null);
        super.new(path, parent);
        tr = transaction::type_id::create("tr");
        if(!uvm_config_db#(virtual spi_i)::get(this,"","vif",vif))
            `uvm_error("DRV", "Unable to access the interface");
    endfunction

   virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(tr);
                if(tr.op == rstdut) begin
                    vif.rst <= 1'b1;
                    vif.cs <= 1'b1;
                    vif.miso <= 1'b1;
                    `uvm_info("DRV", "System reset detected", UVM_NONE);
                    @(posedge vif.clk);
                end

                else if(tr.op == writed) begin
                    vif.rst <= 1'b0;
                    vif.cs <= 1'b0;
                    vif.miso <= 1'b0;
                    `uvm_info("DRV", $sformatf("DATA WRITE addr: %0d, din: %0d", tr.addr, tr.din), UVM_NONE);
                    @(posedge vif.clk);
                    vif.miso <= 1'b1;//write
                    @(posedge vif.clk);

                    // for(int i = 0; i < 16; i ++) begin
                    //     vif.miso <= data[i];
                    //     @(posedge vif.clk);
                    // end

                    for(int i = 0; i < 8 ; i++) begin
                        vif.miso <= tr.addr[i];
                        @(posedge vif.clk);
                    end
                    for(int i = 0; i < 8; i++) begin
                        vif.miso <= tr.din[i];
                        @(posedge vif.clk);
                    end

                    @(posedge vif.op_done);
                end

                else if(tr.op == readd) begin
                    vif.rst <= 1'b0;
                    vif.cs <= 1'b0;
                    vif.miso <= 1'b0;
                    @(posedge vif.clk);
                    vif.miso <= 1'b0;
                    @(posedge vif.clk);

                    //send addr
                    for(int i = 0; i < 8; i++) begin
                        vif.miso <= tr.addr[i];
                        @(posedge vif.clk);
                    end

                    //wait for data ready
                    @(posedge vif.ready);
                    
                    //sample output data
                    for(int i = 0; i < 8; i++) begin
                        @(posedge vif.clk);
                        datard[i] = vif.mosi;
                    end
                    `uvm_info("DRV", $sformatf("Data read addr: %0d, dout: %0d", tr.addr, datard), UVM_NONE);
                    @(posedge vif.op_done);
                    vif.cs <= 1'b1;
                end
            seq_item_port.item_done();

        end
    endtask
endclass



        
    