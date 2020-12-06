module transfer_bridge(
    input               aclk,
    input               aresetn,

    //read request
    output  [ 3:0]      arid,
    output  [31:0]      araddr,
    output  [ 7:0]      arlen,
    output  [ 2:0]      arsize,
    output  [ 1:0]      arburst,
    output  [ 1:0]      arlock,
    output  [ 3:0]      arcache,
    output  [ 2:0]      arprot,
    output              arvalid,
    input               arready,

    //read response
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,

    //write request
    output  [ 3:0]      awid,
    output  [31:0]      awaddr,
    output  [ 7:0]      awlen,
    output  [ 2:0]      awsize,
    output  [ 1:0]      awburst,
    output  [ 1:0]      awlock,
    output  [ 3:0]      awcache,
    output  [ 2:0]      awprot,
    output              awvalid,
    input               awready,

    //write data
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

    //write response
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready,

    //scram inst
    input               inst_sram_req,
    input               inst_sram_wr,
    input   [ 1:0]      inst_sram_size,
    input   [31:0]      inst_sram_addr,
    input   [ 3:0]      inst_sram_wstrb,
    input   [31:0]      inst_sram_wdata,
    output              inst_sram_addr_ok,
    output              inst_sram_data_ok,
    output  [31:0]      inst_sram_rdata,

    //scram data
    input               data_sram_req,
    input               data_sram_wr,
    input   [ 1:0]      data_sram_size,
    input   [31:0]      data_sram_addr,
    input   [31:0]      data_sram_wdata,
    input   [ 3:0]      data_sram_wstrb,
    output              data_sram_addr_ok,
    output              data_sram_data_ok,
    output  [31:0]      data_sram_rdata
);
// some constant
// ID
parameter INST_ID = 4'h0;
parameter DATA_ID = 4'h1;

// read request
assign arlen    = 0;
assign arburst  = 2'b01;
assign arlock   = 2'b00;
assign arcache  = 4'b0000;
assign arprot   = 3'b000;
// write request
assign awid     = 4'b0001;
assign awlen    = 8'b00000000;
assign awburst  = 2'b01;
assign awlock   = 2'b00;
assign awcache  = 4'b0000;
assign awprot   = 3'b000;
// write data
assign wid      = 4'b0001;
assign wlast    = 1;

/************ define ************/
/* AXI read request */
reg         axi_ar_busy;
reg  [ 3:0] axi_ar_id;
reg  [31:0] axi_ar_addr;
reg  [ 2:0] axi_ar_size;

/* AXI read response */
wire        axi_r_data_ok;
wire        axi_r_inst_ok;
wire [31:0] axi_r_data;

/* AXI write request */
reg         axi_aw_busy;
reg  [31:0] axi_aw_addr;
reg  [ 2:0] axi_aw_size;
reg         axi_w_busy;
reg  [31:0] axi_w_data;
reg  [ 3:0] axi_w_strb;

/* AXI write response */
wire        axi_b_ok;

/* middle read request */
wire        read_req_sel_data;
wire        read_req_sel_inst;

wire        read_req_valid;
wire [ 3:0] read_req_id;
wire [31:0] read_req_addr;
wire [ 2:0] read_req_size;

wire        read_data_req_ok;
wire        read_inst_req_ok;

/* middle read inst response */
wire        read_inst_resp_wen;
wire        read_inst_resp_ren;
wire        read_inst_resp_empty;
wire        read_inst_resp_full;
wire [31:0] read_inst_resp_input;
wire [31:0] read_inst_resp_output;
fifo_buffer #(
    .DATA_WIDTH     (32),
    .BUFF_DEPTH     (6),
    .ADDR_WIDTH     (3)
) read_inst_resp_buff (
    .clk            (aclk),
    .resetn         (aresetn),
    .wen            (read_inst_resp_wen),
    .ren            (read_inst_resp_ren),
    .empty          (read_inst_resp_empty),
    .full           (read_inst_resp_full),
    .input_data     (read_inst_resp_input),
    .output_data    (read_inst_resp_output)
);

/* middle read data response */
wire        read_data_resp_wen;
wire        read_data_resp_ren;
wire        read_data_resp_empty;
wire        read_data_resp_full;
wire [31:0] read_data_resp_input;
wire [31:0] read_data_resp_output;
fifo_buffer #(
    .DATA_WIDTH     (32),
    .BUFF_DEPTH     (6),
    .ADDR_WIDTH     (3)
) read_data_resp_buff (
    .clk            (aclk),
    .resetn         (aresetn),
    .wen            (read_data_resp_wen),
    .ren            (read_data_resp_ren),
    .empty          (read_data_resp_empty),
    .full           (read_data_resp_full),
    .input_data     (read_data_resp_input),
    .output_data    (read_data_resp_output)
);

/* middle write request */
wire        write_req_valid;
wire [31:0] write_req_addr;
wire [ 2:0] write_req_size;
wire [31:0] write_req_data;
wire [ 3:0] write_req_strb;
wire        write_data_req_ok;

/* middle write response */
wire        write_data_resp_wen;
wire        write_data_resp_ren;
wire        write_data_resp_empty;
wire        write_data_resp_full;
fifo_count #(
    .BUFF_DEPTH     (6),
    .ADDR_WIDTH     (3)
) write_data_resp_count (
    .clk            (aclk),
    .resetn         (aresetn),
    .wen            (write_data_resp_wen),
    .ren            (write_data_resp_ren),
    .empty          (write_data_resp_empty),
    .full           (write_data_resp_full)
);

/* SRAM inst request */
wire        inst_read_valid;
wire        inst_related;  // TODO

/* SRAM inst response */
wire        inst_read_ready;

/* SRAM data request */
wire        data_read_valid;
wire        data_write_valid;
wire        data_related;   

// request record
wire        data_req_record_wen;
wire        data_req_record_ren;
wire        data_req_record_empty;
wire        data_req_record_full;
wire        data_req_record_related_1;
wire [32:0] data_req_record_input;      // {wr, addr}
wire [32:0] data_req_record_output;     // {wr, addr}
fifo_buffer_valid #(
    .DATA_WIDTH     (33),
    .BUFF_DEPTH     (6),
    .ADDR_WIDTH     (3),
    .RLAT_WIDTH     (32)
) data_req_record (
    .clk            (aclk),
    .resetn         (aresetn),
    .wen            (data_req_record_wen),
    .ren            (data_req_record_ren),
    .empty          (data_req_record_empty),
    .full           (data_req_record_full),
    .related_1      (data_req_record_related_1),
    .input_data     (data_req_record_input),
    .output_data    (data_req_record_output),
    .related_data_1 (data_sram_addr)
);

/* SRAM data response */
wire        data_read_ready;
wire        data_write_ready;


/************ assign ************/
/* AXI read request */
always @ (posedge aclk) begin
    if (!aresetn) begin
        axi_ar_busy <= 1'b0;
        axi_ar_id   <= 4'h0;
        axi_ar_addr <= 32'h0;
        axi_ar_size <= 3'h0;
    end else if (!axi_ar_busy && read_req_valid) begin
        axi_ar_busy <= 1'b1;
        axi_ar_id   <= read_req_id;
        axi_ar_addr <= read_req_addr;
        axi_ar_size <= read_req_size;
    end else if (axi_ar_busy && arvalid && arready) begin
        axi_ar_busy <= 1'b0;
        axi_ar_id   <= 4'h0;
        axi_ar_addr <= 32'h0;
        axi_ar_size <= 3'h0;
    end
end
assign arvalid  = axi_ar_busy;
assign arid     = axi_ar_id;
assign araddr   = axi_ar_addr;
assign arsize   = axi_ar_size;

/* AXI read response */
assign axi_r_data_ok = rvalid && rready && rid == DATA_ID;
assign axi_r_inst_ok = rvalid && rready && rid == INST_ID;
assign axi_r_data    = rdata;

assign rready = !read_inst_resp_full && !read_data_resp_full;

/* AXI write request */
always @ (posedge aclk) begin
    if (!aresetn) begin
        axi_aw_busy <= 1'b0;
        axi_aw_addr <= 32'h0;
        axi_aw_size <= 3'h0;
    end else if (!axi_aw_busy && !axi_w_busy && write_req_valid) begin
        axi_aw_busy <= 1'b1;
        axi_aw_addr <= write_req_addr;
        axi_aw_size <= write_req_size;
    end else if (axi_aw_busy && awvalid && awready) begin
        axi_aw_busy <= 1'b0;
        axi_aw_addr <= 32'h0;
        axi_aw_size <= 3'h0;
    end
    if (!aresetn) begin
        axi_w_busy  <= 1'b0;
        axi_w_data  <= 32'h0;
        axi_w_strb  <= 4'h0;
    end else if (!axi_aw_busy && !axi_w_busy && write_req_valid) begin
        axi_w_busy  <= 1'b1;
        axi_w_data  <= write_req_data;
        axi_w_strb  <= write_req_strb;
    end else if (axi_w_busy && wvalid && wready) begin
        axi_w_busy  <= 1'b0;
        axi_w_data  <= 32'h0;
        axi_w_strb  <= 4'h0;
    end
end
assign awvalid  = axi_aw_busy;
assign wvalid   = axi_w_busy;
assign awaddr   = axi_aw_addr;
assign awsize   = axi_aw_size;
assign wdata    = axi_w_data;
assign wstrb    = axi_w_strb;

/* AXI write response */
assign axi_b_ok = bvalid && bready;
assign bready = !write_data_resp_full;

/* middle read request */
assign read_req_sel_data    = data_read_valid;
assign read_req_sel_inst    = !data_read_valid && inst_read_valid;;

// to axi
assign read_req_valid       = inst_read_valid || data_read_valid;
assign read_req_id          = read_req_sel_data ? DATA_ID : INST_ID;
assign read_req_addr        = read_req_sel_data ? data_sram_addr : inst_sram_addr;
assign read_req_size        = read_req_sel_data ? data_sram_size : inst_sram_size;

// to sram
assign read_data_req_ok = read_req_sel_data && !axi_ar_busy;
assign read_inst_req_ok = read_req_sel_inst && !axi_ar_busy;

/* middle read inst response */
assign read_inst_resp_ren = inst_read_ready;
assign read_inst_resp_wen = axi_r_inst_ok;
assign read_inst_resp_input = axi_r_data;

/* middle read data response */
assign read_data_resp_ren = data_read_ready;
assign read_data_resp_wen = axi_r_data_ok;
assign read_data_resp_input = axi_r_data;

/* middle write request */
// to axi
assign write_req_valid      = data_write_valid;
assign write_req_addr       = data_sram_addr;
assign write_req_size       = data_sram_size;
assign write_req_data       = data_sram_wdata;
assign write_req_strb       = data_sram_wstrb;

// to sram
assign write_data_req_ok = data_write_valid && !axi_aw_busy && !axi_w_busy;

/* middle write response */
assign write_data_resp_ren = data_write_ready;
assign write_data_resp_wen = axi_b_ok;

/* SRAM inst request */
assign inst_read_valid = inst_sram_req && !inst_sram_wr && !inst_related;
assign inst_sram_addr_ok = read_inst_req_ok;
assign inst_related = 0;

/* SRAM inst response */
assign inst_read_ready = 1;
assign inst_sram_data_ok = !read_inst_resp_empty;
assign inst_sram_rdata = read_inst_resp_output;

/* SRAM data request */
assign data_related      = data_req_record_related_1;
assign data_read_valid   = data_sram_req && !data_sram_wr && !data_related;
assign data_write_valid  = data_sram_req && data_sram_wr && !data_related;
assign data_sram_addr_ok = read_data_req_ok || write_data_req_ok;

// request record
assign data_req_record_ren = data_sram_data_ok;
assign data_req_record_wen = data_sram_req && data_sram_addr_ok;
assign data_req_record_input = {data_sram_wr, data_sram_addr};

/* SRAM data response */
assign data_sram_rdata  = read_data_resp_output;
assign data_read_ready  = !data_req_record_empty && !data_req_record_output[32];
assign data_write_ready = !data_req_record_empty && data_req_record_output[32];

assign data_sram_data_ok = 
    (data_read_ready && !read_data_resp_empty) || 
    (data_write_ready && !write_data_resp_empty);

endmodule