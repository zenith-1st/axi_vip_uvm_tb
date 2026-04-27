interface axi_if #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 16,
    parameter STRB_WIDTH     = (DATA_WIDTH/8),
    parameter ID_WIDTH       = 8,
    parameter PIPELINE_OUTPUT = 0
) (input clk, input reset);

    //write addr bus
    logic [ID_WIDTH-1:0]    awid;
    logic [ADDR_WIDTH-1:0]  awaddr;
    logic [7:0]             awlen;
    logic [2:0]             awsize;
    logic [1:0]             awburst;
    logic                   awlock;
    logic [3:0]             awcache;
    logic [2:0]             awprot;
    logic                   awvalid;
    logic                   awready;

    //write data bus
    logic [DATA_WIDTH-1:0]  wdata;
    logic [STRB_WIDTH-1:0]  wstrb;
    logic                   wlast;
    logic                   wvalid;
    logic                   wready;

    //write resp bus
    logic [ID_WIDTH-1:0]    bid;
    logic [1:0]             bresp;
    logic                   bvalid;
    logic                   bready;

    //read addr bus
    logic [ID_WIDTH-1:0]    arid;
    logic [ADDR_WIDTH-1:0]  araddr;
    logic [7:0]             arlen;
    logic [2:0]             arsize;
    logic [1:0]             arburst;
    logic                   arlock;
    logic [3:0]             arcache;
    logic [2:0]             arprot;
    logic                   arvalid;
    logic                   arready;

    //read data bus
    logic [ID_WIDTH-1:0]    rid;
    logic [DATA_WIDTH-1:0]  rdata;
    logic [1:0]             rresp;
    logic                   rlast;
    logic                   rvalid;
    logic                   rready;

    //clocking and modport for deiver
    clocking driver_cb @(posedge clk);
        default input #1step output #1;

        //WRITE ADDRESS BUS
        input  awready;
        output awid, awaddr, awlen, awsize, awburst, awvalid, awcache, awprot, awlock;

        //WRITE DATA BUS
        input  wready;
        output wdata, wstrb, wlast, wvalid;

        //WRITE RESPONSE BUS
        input  bid, bresp, bvalid;
        output bready;

        //READ ADDRESS BUS
        input  arready;
        output arid, araddr, arlen, arsize, arburst, arvalid, arcache, arprot, arlock;

        //READ DATA BUS
        input  rid, rdata, rresp, rlast, rvalid;
        output rready;

    endclocking

    modport driver_mp (clocking driver_cb, input clk, reset);

    //clocking and modport for the monitor

    clocking monitor_cb @(posedge clk);
        default input #1step;

        //WRITE ADDRESS BUS
        input awready;
        input awid, awaddr, awlen, awsize, awburst, awvalid, awcache, awprot, awlock;

        //WRITE DATA BUS
        input wready;
        input wdata, wstrb, wlast, wvalid;

        //WRITE RESPONSE BUS
        input bid, bresp, bvalid;
        input bready;

        //READ ADDRESS BUS
        input arready;
        input arid, araddr, arlen, arsize, arburst, arvalid, arcache, arprot, arlock;

        //READ DATA BUS
        input rid, rdata, rresp, rlast, rvalid;
        input rready;

    endclocking

    modport monitor_mp (clocking monitor_cb, input clk, reset);

endinterface
