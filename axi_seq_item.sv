class axi_seq_item extends uvm_sequence_item;
  `uvm_object_utils(axi_seq_item)

  function new(string name="axi_seq_item");
    super.new(name);
  endfunction

  rand bit reset;

  //WRITE ADDRESS BUS
  rand bit  [7:0]        awid;
  rand bit  [15:0]       awaddr;
  rand bit  [7:0]        awlen;
  rand bit  [2:0]        awsize;
  rand bit  [1:0]        awburst;
  bit                    awlock;
  bit       [3:0]        awcache;
  bit       [2:0]        awprot;
  // awvalid is driven by the driver as part of handshake, not randomized
  bit                    awvalid;
  bit                    awready;

  //WRITE DATA BUS
  // wdata is a dynamic array — size is constrained to awlen+1 (one entry per beat)
  rand bit  [31:0]       wdata[];
  rand bit  [3:0]        wstrb;
  // wlast is driven by the driver after the final beat, not randomized
  bit                    wlast;
  // wvalid is driven by the driver as part of handshake, not randomized
  bit                    wvalid;
  bit                    wready;

  //WRITE RESPONSE BUS
  bit       [7:0]        bid;
  bit       [1:0]        bresp;
  bit                    bvalid;
  // bready is driven by the driver to accept the response, not randomized
  bit                    bready;

  //READ ADDRESS BUS
  rand bit  [7:0]        arid;
  rand bit  [15:0]       araddr;
  rand bit  [7:0]        arlen;
  rand bit  [2:0]        arsize;
  rand bit  [1:0]        arburst;
  bit                    arlock;
  bit       [3:0]        arcache;
  bit       [2:0]        arprot;
  // arvalid is driven by the driver as part of handshake, not randomized
  bit                    arvalid;
  bit                    arready;

  //READ DATA BUS
  bit       [7:0]        rid;
  bit       [31:0]       rdata[];
  bit       [1:0]        rresp;
  bit                    rlast;
  bit                    rvalid;
  // rready is driven by the driver to accept read data, not randomized
  bit                    rready;

  // IDs kept non-zero (0 is often reserved) and within 4-bit range
  constraint id_c {
    awid inside {[1:15]};
    arid inside {[1:15]};
  }

  // Default to INCR burst (awburst==1) — most commonly used in AXI4
  // soft allows sequences to override this when needed (e.g. WRAP tests)
  constraint burst_c {
    soft awburst == 2'b01;
    soft arburst == 2'b01;
  }

  // Default burst length of 4 beats (awlen==3 means 4 beats, AXI len is len+1)
  // soft allows sequences to override for longer/shorter burst tests
  constraint length_c {
    soft awlen == 8'd3;
    soft arlen == 8'd3;
  }

  // wdata array size must match burst length — one data beat per transfer
  // awlen==3 means 4 beats, so wdata must have 4 entries
  constraint wdata_size_c {
    wdata.size() == awlen + 1;
  }

  // Keep all byte lanes active by default (full 32-bit word writes)
  // soft allows sequences to test partial writes (e.g. byte/halfword strobes)
  constraint strobe_c {
    soft wstrb == 4'b1111;
  }

  // awsize==2 means 4 bytes per beat, matching our 32-bit DATA_WIDTH
  // soft allows sequences to test narrow transfers
  constraint size_c {
    soft awsize == 3'd2;
    soft arsize == 3'd2;
  }

  // Addresses must be naturally aligned to the transfer size
  // awsize==2 (4 bytes) requires addr[1:0]==0 to avoid unaligned access errors
  constraint addr_align_c {
    soft awaddr[1:0] == 2'b00;
    soft araddr[1:0] == 2'b00;
  }

  // AXI rule: a burst must not cross a 4KB address boundary.
  // Total bytes transferred = (len+1) * (2^size).
  // addr[11:0] + total_bytes must stay within the same 4KB page (<=4096).
  // e.g. awlen==3, awsize==2 => 4*4=16 bytes, so addr[11:0] must be <=4080.
  constraint boundary_4k_c {
    soft awaddr[11:0] <= (12'd4096 - ((awlen + 1) * (1 << awsize)));
    soft araddr[11:0] <= (12'd4096 - ((arlen + 1) * (1 << arsize)));
  }

  // AXI WRAP burst requires length to be exactly 2, 4, 8, or 16 beats
  // (i.e. awlen must be 1, 3, 7, or 15). INCR and FIXED have no restriction.
  constraint len_wrap_c {
    if (awburst == 2'b10) awlen inside {8'd1, 8'd3, 8'd7, 8'd15};
    if (arburst == 2'b10) arlen inside {8'd1, 8'd3, 8'd7, 8'd15};
  }

endclass
