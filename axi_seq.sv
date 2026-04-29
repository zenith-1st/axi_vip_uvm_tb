// axi_seq is the base seq
class axi_seq extends uvm_sequence;
  `uvm_object_utils(axi_seq)

  function new(string name="axi_seq");
    super.new(name);
  endfunction

endclass


// seq_1: INCR burst, equal write and read length
class sequence_1 extends axi_seq;
  `uvm_object_utils(sequence_1)

  function new(string name="sequence_1");
    super.new(name);
  endfunction

  task body();
    axi_seq_item trans;

    // Assert reset first
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with { reset == 1; })
      `uvm_fatal("SEQ1", "Randomization failed for reset phase")
    finish_item(trans);

    // Main transaction: INCR burst, awlen==arlen==4 (5 beats)
    // awaddr and araddr constrained to stay within 4KB boundary:
    //   (awlen+1)*4 = 20 bytes, so addr[11:0] <= 4076
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with {
          reset          == 0;
          awburst        == 2'b01;          // INCR
          arburst        == 2'b01;
          awlen          == 8'd4;           // 5 beats
          arlen          == awlen;
          awsize         == 3'd2;           // 4 bytes per beat
          arsize         == 3'd2;
          awaddr[1:0] == 2'b00;          // 4-byte aligned
          araddr[1:0] == 2'b00;
          // 4KB boundary: addr[11:0] + (awlen+1)*4 <= 4096
          awaddr[11:0] <= (16'd4096 - ((awlen + 1) * (1 << awsize)));
          araddr[11:0] <= (16'd4096 - ((arlen + 1) * (1 << arsize)));
          wstrb          == 4'b1111;
          wdata.size()   == (awlen + 1);
          unique { wdata };
        })
      `uvm_fatal("SEQ1", "Randomization failed for main transaction")
    finish_item(trans);
    `uvm_info("SEQ1", $sformatf("Done: INCR burst awlen=%0d arlen=%0d awaddr=0x%0h", trans.awlen, trans.arlen, trans.awaddr), UVM_HIGH)
  endtask

endclass


// seq_2: INCR burst, different write and read lengths
// Note: awlen and arlen are independent — it is perfectly valid for arlen > awlen.
// Write and read use separate AXI channels with no length dependency.
class sequence_2 extends axi_seq;
  `uvm_object_utils(sequence_2)

  function new(string name="sequence_2");
    super.new(name);
  endfunction

  task body();
    axi_seq_item trans;

    // Assert reset first
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with { reset == 1; })
      `uvm_fatal("SEQ2", "Randomization failed for reset phase")
    finish_item(trans);

    // Main transaction: write 9 beats, read 5 beats (independent lengths)
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with {
          reset          == 0;
          awburst        == 2'b01;          // INCR
          arburst        == 2'b01;
          awlen          == 8'd8;           // 9 beats
          arlen          == 8'd4;           // 5 beats (independent of awlen)
          awsize         == 3'd2;
          arsize         == 3'd2;
          awaddr[1:0] == 2'b00;
          araddr[1:0] == 2'b00;
          awaddr[11:0] <= (16'd4096 - ((awlen + 1) * (1 << awsize)));
          araddr[11:0] <= (16'd4096 - ((arlen + 1) * (1 << arsize)));
          wstrb          == 4'b1111;
          wdata.size()   == (awlen + 1);
          unique { wdata };
        })
      `uvm_fatal("SEQ2", "Randomization failed for main transaction")
    finish_item(trans);
    `uvm_info("SEQ2", $sformatf("Done: INCR burst awlen=%0d arlen=%0d", trans.awlen, trans.arlen), UVM_HIGH)
  endtask

endclass


// seq_3: INCR burst, different transfer sizes for write and read
// awsize==2 (4 bytes/beat) vs arsize==1 (2 bytes/beat)
// This tests narrow read transfers against full-width writes
class sequence_3 extends axi_seq;
  `uvm_object_utils(sequence_3)

  function new(string name="sequence_3");
    super.new(name);
  endfunction

  task body();
    axi_seq_item trans;

    // Assert reset first
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with { reset == 1; })
      `uvm_fatal("SEQ3", "Randomization failed for reset phase")
    finish_item(trans);

    // Main transaction: write with 4-byte beats, read with 2-byte beats
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with {
          reset          == 0;
          awburst        == 2'b01;          // INCR
          arburst        == 2'b01;
          awlen          == 8'd8;
          arlen          == 8'd8;
          awsize         == 3'd2;           // 4 bytes per beat (full width)
          arsize         == 3'd1;           // 2 bytes per beat (narrow read)
          // align to the larger of the two sizes (4 bytes)
          awaddr[1:0] == 2'b00;
          araddr[0]   == 1'b0;           // 2-byte aligned for arsize==1
          awaddr[11:0] <= (16'd4096 - ((awlen + 1) * (1 << awsize)));
          araddr[11:0] <= (16'd4096 - ((arlen + 1) * (1 << arsize)));
          wstrb          == 4'b1111;
          wdata.size()   == (awlen + 1);
          unique { wdata };
        })
      `uvm_fatal("SEQ3", "Randomization failed for main transaction")
    finish_item(trans);
    `uvm_info("SEQ3", $sformatf("Done: awsize=%0d arsize=%0d", trans.awsize, trans.arsize), UVM_HIGH)
  endtask

endclass


// seq_4: Unaligned address test
// awaddr is intentionally unaligned (addr[1:0] != 2'b00)
// wstrb uses partial lanes to match the unaligned offset
// This tests DUT handling of narrow/unaligned transfers
class sequence_4 extends axi_seq;
  `uvm_object_utils(sequence_4)

  function new(string name="sequence_4");
    super.new(name);
  endfunction

  task body();
    axi_seq_item trans;

    // Assert reset first
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with { reset == 1; })
      `uvm_fatal("SEQ4", "Randomization failed for reset phase")
    finish_item(trans);

    // Unaligned write: addr=0x03E8 (1000 decimal), addr[1:0]==2'b00 actually aligned
    // Unaligned read:  addr=0x03EA (1002 decimal), addr[1:0]==2'b10 — 2-byte unaligned
    // wstrb=4'b1100 — upper 2 bytes valid, matching the 2-byte offset of read addr
    // 4KB check: 1002 + 5*4 = 1022, well within 4KB page
    trans = axi_seq_item::type_id::create("trans");
    start_item(trans);
    if (!trans.randomize() with {
          reset       == 0;
          awburst     == 2'b01;
          arburst     == 2'b01;
          awlen       == 8'd4;
          arlen       == 8'd4;
          awsize      == 3'd2;
          arsize      == 3'd2;
          awaddr   == 16'd1000;          // 0x03E8, 4-byte aligned
          araddr   == 16'd1002;          // 0x03EA, intentionally unaligned by 2
          // partial strobe matches the 2-byte offset — upper 2 lanes active
          wstrb       == 4'b1100;
          wdata.size() == (awlen + 1);
          unique { wdata };
        })
      `uvm_fatal("SEQ4", "Randomization failed for main transaction")
    finish_item(trans);
    `uvm_info("SEQ4", $sformatf("Done: unaligned araddr=0x%0h wstrb=%b", trans.araddr, trans.wstrb), UVM_HIGH)
  endtask

endclass
