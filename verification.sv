`include "uvm_macros.svh"
import uvm_pkg::*;

class spi_config extends uvm_object;
    `uvm_object_utils(spi_config)

    function new(string path = "spi_config");
        super.new(path);
    endfunction

    uvm_active_passive_enum is_active = UVM_ACTIVE;
endclass

//enum used to specify the operation mode
typedef enum bit [2:0] {readd = 0, writed = 1, rstdut = 2, writeerr = 3, readerr = 4} oper_mode;

class transaction extends uvm_sequence_item;

    rand oper_mode op; //declare the operation mode enum 
        //specify all the inputs and outputs of SPI
         logic rst;
         logic wr;
    rand logic [7:0] addr;
    rand logic [7:0] din;
         logic done;
         logic [7:0] dout;
         logic err;
    
    `uvm_object_utils_begin(transaction)
         `uvm_field_int(rst, UVM_ALL_ON)
         `uvm_field_int(wr, UVM_ALL_ON)
         `uvm_field_int(addr, UVM_ALL_ON)
         `uvm_field_int(din, UVM_ALL_ON)
         `uvm_field_int(done, UVM_ALL_ON)
         `uvm_field_int(dout, UVM_ALL_ON)
         `uvm_field_int(err, UVM_ALL_ON)
         `uvm_field_enum(oper_mode, op, UVM_DEFAULT)
    `uvm_object_utils_end
    
    function new(string path = "transaction");
        super.new(path);
    endfunction

    //two constraints to specify the address range
    constraint addr_c { addr <= 10;}    //valid address
    constraint addr_c_err {addr > 31}   //invalid address

endclass

//for sequence we have different sequence classes depending on which mode you operate

//write seq 
class write_data extends uvm_sequence#(transaction);
    `uvm_object_utils(write_data)

    transaction trans;

    function new(string path = "write_data")
        super.new(path)
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            tr.addr_c_err.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = writed;
            finish_item(tr);
        end
    endtask
endclass

class write_err extends uvm_sequence#(transaction);
    `uvm_component_utils(write_err)

    transaction tr;

    function new(string path = "write_err");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c_err.constraint_mode(1);
            tr.addr_c.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = writeerr;
            finish_item(tr);
        end
    endtask
endclass

//read data sequence

class read_data extends uvm_sequence#(transaction);
    `uvm_object_utils(read_data)

    transaction tr;

    function new(string path = "read_data");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            tr.addr_c_err.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = readd;
            finish_item(tr);
        end
    endtask
endclass

class read_err extends uvm_sequence#(transaction);
    `uvm_object_utils(read_err)

    transaction tr;

    function new(string path = "read_err");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(0);
            tr.addr_c_err.constraint_mode(1);
            start_item(tr);
            assert(tr.randomize);
            tr.op = readerr;
            finish_item(tr);
        end
    endtask
endclass

class reset_dut extends uvm_sequence#(transaction);
    `uvm_object_utils(reset_dut)

    transaction tr;

    function new(string path = "reset_dut");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            tr.addr_c_err.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = rstdut;
            finish_item(tr);
        end
    endtask
endclass

//write_read

class writeb_readb extends uvm_sequence#(transaction);
    `uvm_object_utils(writeb_readb)

    transaction tr;

    function new(string path = "reset_dut");
        super.new(path);
    endfunction

    virtual task body();
        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            tr.addr_c_err.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = readd;
            finish_item(tr);
        end

        repeat(15) begin
            tr = transaction::type_id::create("tr");
            tr.addr_c.constraint_mode(1);
            tr.addr_c_err.constraint_mode(0);
            start_item(tr);
            assert(tr.randomize);
            tr.op = writed;
            finish_item(tr);
        end
    endtask
endclass

//driver class
class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    transaction tr;
    virtual spi_i vif;

    function new(string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if(!uvm_config_db#(virtual spi_i)::get(this,"", "vif", vif))
         `uvm_error("drv", "unable access the interface");
    endfunction

    task reset_dut();
        repeat(5) begin
            vif.rst <= 1'b1;
            vif.addr <= 'h0;
            vif.data <= 'h0;
            vif.wr <= 1'b0;
            `uvm_info("DRV", "System RESET: start of simulation", UVM_MEDIUM);
            @(posedge vif.clk);
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        reset_dut();
        forever begin
            seq_item_port.get_next_item(tr);

                if(tr.op == rstdut) begin
                    vif.rst <= 1'b1;
                    @(posedge vif.clk);
                end

                else if(tr.op == readd) begin
                    vif.rst <= 1'b0;
                    vif.wr <= 1'b0;
                    vif.addr <= tr.addr;
                    vif.din <= tr.din;
                    @(posedge vif.clk);
                    `uvm_info("DRV", $sformatf("mode: Read, addr: %0d, din: %0d", vif.addr, vif.din), UVM_NONE);
                    @(posedge vif.done);
                end

                else if(tr.op == writed) begin
                    vif.rst <= 1'b0;
                    vif.wr <= 1'b1;
                    vif.addr <= tr.addr;
                    vif.din <= tr.din;
                    @(posedge vif.clk);
                    `uvm_info("DRV", $sformatf("mode: Write, addr: %0d, din: %0d", vif.addr, vif.din), UVM_NONE);
                    @(posedge vif.done);
                end
            seq_item_port.item_done();
        end
    endtask
endclass


//monitor 
class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    

    transaction tr;
    virtual spi_i vif;
    uvm_analysis_port#(transaction) send;

    covergroup cg_spi;
        coverpoint tr.op {
            bins read_op  = {readd};
            bins write_op = {writed};
            bins reset_op = {rstdut};
            bins err_read = {readerr};
            bins err_write = {writeerr};
        }

        coverpoint tr.addr {
            bins valid_addr = {[0:10]};
            bins invalid_addr = {[31:255]};
        }
    endgroup

    function new(string path = "monitor", uvm_component parent = null);
        super.new(path, parent);
        cg_spi = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        send = new("send", this);
        if(!uvm_config_db#(virtual spi_i)::get(this,"","vi", vif))
         `uvm_error("MON", "Unable to access the interface");
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if(vif.rst) begin
                tr.op = rstdut;
                `uvm_info("MON", "System RESET DETECTED", UVM_NONE);
                send.write(tr);
            end
            else if(!vif.rst && vif.wr) begin
                tr.op = writed;
                tr.addr = vif.addr;
                tr.din = vif.din;
                tr.err = vif.err;
                cg_spi.sample();
                `uvm_info("MON", $sformatf("Write Mode: din: %0d, addr: %0d, err: %0d", tr.din, tr.addr, tr.err), UVM_NONE);
                send.write(tr);
            end
            else if(!vif.rst && !vif.wr) begin
                tr.op = readd;
                tr.addr = vif.addr;
                tr.din = vif.din;
                tr.err = vif.err;
                cg_spi.sample();
                `uvm_info("MON", $sformatf("Read Mode: din: %0d, addr: %0d, err: %0d", tr.din, tr.addr, tr.err), UVM_NONE);
                send.write(tr);
            end
        end
    endtask
endclass

//scoreboard
class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    function new(string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    uvm_analysis_imp#(transaction, scoreboard) recv;
    bit [31:0] arr[32] = '{default:0};
    bit [31:0] addr = 0;
    bit [31:0] data_rd = 0;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        recv = new("recv", this);
    endfunction

    virtual task write(uvm_phase phase);
        if(tr.op = rstdut) begin
            `uvm_info("SCO", "SYSTEM RESET DETECTED", UVM_NONE);
        end
        else if(tr.op == writed) begin
            if(tr.err = 1'b1) begin
                `uvm_info("SCO", "SLV error during WRITE OP", UVM_NONE);
            end
            else begin
                arr[tr.addr] = tr.din;
                `uvm_info("SCO", $sformatf("Data write OP, addr: %0d, wdata: %0d, arr_wr: %0d", tr.addr, tr.din, data_rd), UVM_NONE)
            end
        end
        else if(tr.op == readd) begin
            if(tr.err = 1'b1) begin
                `uvm_info("SCO", "SLV Error during Read Op", UVM_NONE);
            end
            else begin
                data_rd =  arr[tr.addr];     
                if(data_rd == tr.dout)
                 `uvm_info("SCO", $sformatf("Data Matched addr: %0d, rdata: %0d data_rd_arr: %0d", tr.addr, tr.dout, data_rd), UVM_NONE);
                else
                 `uvm_info("SCO", $sformatf("TEST FAILED addr: %0d, rdata: %0d, data_rd_arr: %0d", tr.addr, tr.dout, data_rd), UVM_NONE);
            end
        end
    endtask
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    spi_config cfg;
    driver d;
    monitor m;
    uvm_sequencer#(transaction) seqr;

    function new(string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = spi_config::type_id::create("cfg");
        m = monitor::type_id::create("m", this);

        if(cfg.is_active == UVM_ACTIVE) begin
            d = driver::type_id::create("d", this);
            seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if(cfg.is_active == UVM_ACTIVE) begin
            d.seq_item_port.connect(seqr.seq_item_export);
        end
    endfunction
endclass

class env extends uvm_env;
    `uvm_component_utils(env)

    function new(string path = "env", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    agent a;
    scoreboard s;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a", this);
        s = scoreboard::type_id::create("s", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.m.send.connect(s.recv);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    function new(string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    env e;
    //sequences

    write_data wdata;
    write_err werr;

    read_data rdata;
    read_err rerr;

    writeb_readb wrrdb;
    reset_dut rstdut;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        e = env::type_id::create("e", this);
        wdata = write_data::type_id::create("wdata");
        werr = write_err::type_id::create("werr");
        rdata = read_data::type_id::create("rdata");
        rerr = read_err::type_id::create("rerr");
        wrrdb = writeb_readb::type_id::create("wrrdb");
        rerr = read_err::type_id::create("rerr");
        wrrdb = writeb_readb::type_id::create("wrrb");
        rstdut = reset_dut::type_id::create("rstdut");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        wrrdb.start(e.a.seqr);
        #20;
        phase.drop_objection(this);
    endtask
endclass

module tb;

    spi_i vif();

    top dut (.wr(vif.wr), .addr(vif.addr), .din(vif.din), .clk(vif.clk), .rst(vif.rst), .dout(vif.dout), .done(vif.done), .err(vif.done));

    initial begin
        vif.clk <= 0;
    end

    always #10 vif.clk <= ~vif.clk;

    initial begin
        uvm_config_db#(virtual spi_i)::set(null, "*", "vif", vif);
        run_test("test");
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule