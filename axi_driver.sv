class axi_driver extends uvm_driver#(axi_seq_item);
  `uvm_component_utils(axi_driver)

  function new(string name="axi_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  // Parameters must match the axi_if instantiation in the testbench top
  virtual axi_if #(.DATA_WIDTH(32), .ADDR_WIDTH(16)) intf;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if #(.DATA_WIDTH(32), .ADDR_WIDTH(16)))::get(this, "", "intf", intf))
      `uvm_fatal("DRIVER", "Could not get virtual interface handle from config_db")
  endfunction

  // -----------------------------------------------------------------------
  // run_phase: main driver loop
  // -----------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    axi_seq_item item;

    // Drive all outputs to safe idle state before any transaction
    init_signals();

    forever begin
      seq_item_port.get_next_item(item);

      if (item.reset)
        drive_reset();
      else begin
        // AW/W/B and AR/R are independent channels — fork to drive concurrently
        fork
          drive_write(item);
          drive_read(item);
        join
      end

      seq_item_port.item_done();
    end
  endtask

  // -----------------------------------------------------------------------
  // init_signals: drive all outputs to a safe idle state
  // -----------------------------------------------------------------------
  task init_signals();
    @(intf.driver_cb);
    intf.driver_cb.awvalid <= 0;
    intf.driver_cb.awid    <= 0;
    intf.driver_cb.awaddr  <= 0;
    intf.driver_cb.awlen   <= 0;
    intf.driver_cb.awsize  <= 0;
    intf.driver_cb.awburst <= 0;
    intf.driver_cb.awlock  <= 0;
    intf.driver_cb.awcache <= 0;
    intf.driver_cb.awprot  <= 0;

    intf.driver_cb.wvalid  <= 0;
    intf.driver_cb.wdata   <= 0;
    intf.driver_cb.wstrb   <= 0;
    intf.driver_cb.wlast   <= 0;

    intf.driver_cb.bready  <= 0;

    intf.driver_cb.arvalid <= 0;
    intf.driver_cb.arid    <= 0;
    intf.driver_cb.araddr  <= 0;
    intf.driver_cb.arlen   <= 0;
    intf.driver_cb.arsize  <= 0;
    intf.driver_cb.arburst <= 0;
    intf.driver_cb.arlock  <= 0;
    intf.driver_cb.arcache <= 0;
    intf.driver_cb.arprot  <= 0;

    intf.driver_cb.rready  <= 0;
  endtask

  // -----------------------------------------------------------------------
  // drive_reset: idle all signals and hold for 5 cycles
  // -----------------------------------------------------------------------
  task drive_reset();
    `uvm_info("DRIVER", "Asserting reset", UVM_MEDIUM)
    init_signals();
    repeat(5) @(intf.driver_cb);
    `uvm_info("DRIVER", "Deasserting reset", UVM_MEDIUM)
  endtask

  // -----------------------------------------------------------------------
  // drive_write: sequences AW -> W -> B channels
  // -----------------------------------------------------------------------
  task drive_write(axi_seq_item item);
    drive_write_address(item);
    drive_write_data(item);
    drive_write_response(item);
  endtask

  // -----------------------------------------------------------------------
  // drive_write_address: drives AW channel, waits for awready handshake
  // -----------------------------------------------------------------------
  task drive_write_address(axi_seq_item item);
    @(intf.driver_cb);
    intf.driver_cb.awvalid <= 1;
    intf.driver_cb.awid    <= item.awid;
    intf.driver_cb.awaddr  <= item.awaddr;
    intf.driver_cb.awlen   <= item.awlen;
    intf.driver_cb.awsize  <= item.awsize;
    intf.driver_cb.awburst <= item.awburst;
    intf.driver_cb.awlock  <= item.awlock;
    intf.driver_cb.awcache <= item.awcache;
    intf.driver_cb.awprot  <= item.awprot;

    // Wait for slave to assert awready (valid+ready handshake)
    @(intf.driver_cb iff intf.driver_cb.awready);

    intf.driver_cb.awvalid <= 0;
    `uvm_info("DRIVER", $sformatf("Write addr accepted: awaddr=0x%0h awlen=%0d", item.awaddr, item.awlen), UVM_HIGH)
  endtask

  // -----------------------------------------------------------------------
  // drive_write_data: drives W channel beat by beat, asserts wlast on final beat
  // -----------------------------------------------------------------------
  task drive_write_data(axi_seq_item item);
    for (int i = 0; i <= item.awlen; i++) begin
      @(intf.driver_cb);
      intf.driver_cb.wvalid <= 1;
      intf.driver_cb.wdata  <= item.wdata[i];
      intf.driver_cb.wstrb  <= item.wstrb;
      // wlast must be high on the final beat only
      intf.driver_cb.wlast  <= (i == item.awlen) ? 1 : 0;

      // Wait for slave to accept this beat
      @(intf.driver_cb iff intf.driver_cb.wready);
    end

    intf.driver_cb.wvalid <= 0;
    intf.driver_cb.wlast  <= 0;
    `uvm_info("DRIVER", $sformatf("Write data done: %0d beats sent", item.awlen+1), UVM_HIGH)
  endtask

  // -----------------------------------------------------------------------
  // drive_write_response: asserts bready, waits for bvalid, checks bresp
  // -----------------------------------------------------------------------
  task drive_write_response(axi_seq_item item);
    @(intf.driver_cb);
    intf.driver_cb.bready <= 1;

    @(intf.driver_cb iff intf.driver_cb.bvalid);

    // OKAY=2'b00, EXOKAY=2'b01, SLVERR=2'b10, DECERR=2'b11
    if (intf.driver_cb.bresp !== 2'b00)
      `uvm_error("DRIVER", $sformatf("Write response error: bresp=0x%0h bid=0x%0h", intf.driver_cb.bresp, intf.driver_cb.bid))

    intf.driver_cb.bready <= 0;
  endtask

  // -----------------------------------------------------------------------
  // drive_read: sequences AR -> R channels
  // -----------------------------------------------------------------------
  task drive_read(axi_seq_item item);
    drive_read_address(item);
    drive_read_data(item);
  endtask

  // -----------------------------------------------------------------------
  // drive_read_address: drives AR channel, waits for arready handshake
  // -----------------------------------------------------------------------
  task drive_read_address(axi_seq_item item);
    @(intf.driver_cb);
    intf.driver_cb.arvalid <= 1;
    intf.driver_cb.arid    <= item.arid;
    intf.driver_cb.araddr  <= item.araddr;
    intf.driver_cb.arlen   <= item.arlen;
    intf.driver_cb.arsize  <= item.arsize;
    intf.driver_cb.arburst <= item.arburst;
    intf.driver_cb.arlock  <= item.arlock;
    intf.driver_cb.arcache <= item.arcache;
    intf.driver_cb.arprot  <= item.arprot;

    @(intf.driver_cb iff intf.driver_cb.arready);

    intf.driver_cb.arvalid <= 0;
    `uvm_info("DRIVER", $sformatf("Read addr accepted: araddr=0x%0h arlen=%0d", item.araddr, item.arlen), UVM_HIGH)
  endtask

  // -----------------------------------------------------------------------
  // drive_read_data: asserts rready, collects beats until rlast, checks rresp
  // -----------------------------------------------------------------------
  task drive_read_data(axi_seq_item item);
    int beat_count = 0;

    @(intf.driver_cb);
    intf.driver_cb.rready <= 1;

    // Collect beats until slave asserts rlast
    do begin
      @(intf.driver_cb iff intf.driver_cb.rvalid);

      if (intf.driver_cb.rresp !== 2'b00)
        `uvm_error("DRIVER", $sformatf("Read response error: rresp=0x%0h beat=%0d", intf.driver_cb.rresp, beat_count))

      `uvm_info("DRIVER", $sformatf("Read beat[%0d]: rdata=0x%0h rlast=%0b", beat_count, intf.driver_cb.rdata, intf.driver_cb.rlast), UVM_HIGH)
      beat_count++;
    end while (!intf.driver_cb.rlast);

    intf.driver_cb.rready <= 0;
    `uvm_info("DRIVER", $sformatf("Read data done: %0d beats received", beat_count), UVM_HIGH)
  endtask

endclass
