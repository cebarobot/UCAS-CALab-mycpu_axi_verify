`include "mycpu.h"
module mycpu_top(
    input         aclk,
    input         aresetn,
    //axi interface
    //read request
    output  [3:0]       arid,
    output  [31:0]      araddr,
    output  [7:0]       arlen,
    output  [2:0]       arsize,
    output  [1:0]       arburst,
    output  [1:0]       arlock,
    output  [3:0]       arcache,
    output  [2:0]       arprot,
    output              arvalid,
    input               arready,

    //read response
    input   [3:0]       rid,
    input   [31:0]      rdata,
    //input   [1:0]       rresp,
    //input               rlast,
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
    //input   [3:0]       bid,
    //input   [1:0]       bresp,
    input               bvalid,
    output              bready,
    
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
//change from output or input(lab10) to wire(lab11)
// inst sram interface
    wire        inst_sram_req;    // TODO
    wire        inst_sram_wr;     // TODO
    wire [ 1:0] inst_sram_size;   // TODO
    wire [ 3:0] inst_sram_wstrb;  // TODO
    wire [31:0] inst_sram_addr;
    wire         inst_sram_addr_ok;// TODO
    wire [31:0] inst_sram_wdata;
    wire  [31:0] inst_sram_rdata;
    wire         inst_sram_data_ok;// TODO
    // data sram interface
    wire        data_sram_req;    // TODO
    wire        data_sram_wr;     // TODO
    wire [ 1:0] data_sram_size;   // TODO
    wire [ 3:0] data_sram_wstrb;  // TODO
    wire [31:0] data_sram_addr;
    wire         data_sram_addr_ok;// TODO
    wire [31:0] data_sram_wdata;
    wire  [31:0] data_sram_rdata;
    wire         data_sram_data_ok;// TODO

//lab10
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

wire         fs_allowin;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         pfs_to_fs_valid;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`PFS_TO_FS_BUS_WD -1:0] pfs_to_fs_bus;
wire [`FS_TO_DS_BUS_WD  -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD  -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD  -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD  -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD  -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD        -1:0] br_bus;
wire [`ES_FWD_BLK_BUS_WD -1:0] es_fwd_blk_bus;
wire [`MS_FWD_BLK_BUS_WD -1:0] ms_fwd_blk_bus;

wire        fs_inst_buff_full;
wire        fs_valid;
wire        ms_data_buff_full;

wire [31:0] cp0_epc;
wire        ws_ex;
wire        ws_eret;
wire [4:0]  ws_rf_dest;
wire        ws_inst_mfc0;

wire        ms_ex;
wire        ms_eret;
wire        ms_inst_mfc0;
wire        es_inst_mfc0;

wire [31:0] cp0_status;
wire [31:0] cp0_cause;


// inst_sram
assign inst_sram_wr     = 1'b0;
assign inst_sram_size   = 2'h2;
assign inst_sram_wstrb  = 4'h0;
assign inst_sram_wdata  = 32'h0;

wire        pfs_inst_waiting;
wire        fs_inst_waiting;
reg  [1:0]  inst_sram_discard;
wire        inst_sram_data_ok_discard;

always @ (posedge aclk) begin
    if (reset) begin
        inst_sram_discard <= 2'b00;
    end else if (ws_ex || ws_eret) begin
        inst_sram_discard <= {pfs_inst_waiting, fs_inst_waiting};
    end else if (inst_sram_data_ok) begin
        if (inst_sram_discard == 2'b11) begin
            inst_sram_discard <= 2'b01;
        end else if (inst_sram_discard == 2'b01) begin
            inst_sram_discard <= 2'b00;
        end else if (inst_sram_discard == 2'b10) begin
            inst_sram_discard <= 2'b00;
        end
    end
end
assign inst_sram_data_ok_discard = inst_sram_data_ok && ~|inst_sram_discard;

// data_sram
wire        es_data_waiting;
wire        ms_data_waiting;
reg  [1:0]  data_sram_discard;
wire        data_sram_data_ok_discard;

always @ (posedge aclk) begin
    if (reset) begin
        data_sram_discard <= 2'b00;
    end else if (ws_ex || ws_eret) begin
        data_sram_discard <= {es_data_waiting, ms_data_waiting};
    end else if (data_sram_data_ok) begin
        if (data_sram_discard == 2'b11) begin
            data_sram_discard <= 2'b01;
        end else if (data_sram_discard == 2'b01) begin
            data_sram_discard <= 2'b00;
        end else if (data_sram_discard == 2'b10) begin
            data_sram_discard <= 2'b00;
        end
    end
end
assign data_sram_data_ok_discard = data_sram_data_ok && ~|data_sram_discard;

// pre-IF stage
pre_if_stage pre_if_stage(
    .clk                    (aclk),
    .reset                  (reset),
    // allowin
    .fs_allowin             (fs_allowin),
    // to fs
    .pfs_to_fs_valid        (pfs_to_fs_valid),
    .pfs_to_fs_bus          (pfs_to_fs_bus),
    // from fs
    .fs_inst_unable         (fs_inst_unable),
    // br_bus
    .br_bus                 (br_bus),
    .fs_valid               (fs_valid),
    // inst_ram interface
    .inst_sram_req          (inst_sram_req),
    .inst_sram_addr         (inst_sram_addr),
    .inst_sram_addr_ok      (inst_sram_addr_ok),
    .inst_sram_rdata        (inst_sram_rdata),
    .inst_sram_data_ok      (inst_sram_data_ok_discard),
    .pfs_inst_waiting       (pfs_inst_waiting),
    .ws_eret                (ws_eret),
    .ws_ex                  (ws_ex),
    .cp0_epc                (cp0_epc)
);

// IF stage
if_stage if_stage(
    .clk                    (aclk),
    .reset                  (reset),
    //allowin
    .ds_allowin             (ds_allowin),
    .fs_allowin             (fs_allowin),
    // from pfs
    .pfs_to_fs_valid        (pfs_to_fs_valid),
    .pfs_to_fs_bus          (pfs_to_fs_bus),
    // to ds
    .fs_to_ds_valid         (fs_to_ds_valid),
    .fs_to_ds_bus           (fs_to_ds_bus),
    // to pfs
    .fs_inst_unable         (fs_inst_unable),
    .fs_valid_o             (fs_valid),
    // inst_ram interface
    .inst_sram_rdata        (inst_sram_rdata),
    .inst_sram_data_ok      (inst_sram_data_ok_discard),
    .fs_inst_waiting        (fs_inst_waiting),
    //exception
    .ws_ex                  (ws_ex),
    .ws_eret                (ws_eret),
    .cp0_epc                (cp0_epc)
);
// ID stage
id_stage id_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // forward & block
    .es_fwd_blk_bus (es_fwd_blk_bus ),
    .ms_fwd_blk_bus (ms_fwd_blk_bus ),
    //exception & block
    .ws_ex          (ws_ex),
    .ws_eret     (ws_eret),
    .es_inst_mfc0   (es_inst_mfc0),
    .ms_inst_mfc0   (ms_inst_mfc0),
    .ws_inst_mfc0   (ws_inst_mfc0),
    .ws_rf_dest     (ws_rf_dest),
    .cp0_cause      (cp0_cause),
    .cp0_status     (cp0_status)
);
// EXE stage
exe_stage exe_stage(
    .clk                    (aclk            ),
    .reset                  (reset          ),
    //allowin
    .ms_allowin             (ms_allowin     ),
    .es_allowin             (es_allowin     ),
    //from ds
    .ds_to_es_valid         (ds_to_es_valid ),
    .ds_to_es_bus           (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid         (es_to_ms_valid ),
    .es_to_ms_bus           (es_to_ms_bus   ),
    //from ms
    .ms_inst_unable         (ms_inst_unable ),
    // data sram interface
    .data_sram_req          (data_sram_req  ),
    .data_sram_wr           (data_sram_wr   ),
    .data_sram_size         (data_sram_size ),
    .data_sram_wdata        (data_sram_wdata),
    .data_sram_wstrb        (data_sram_wstrb),
    .data_sram_addr         (data_sram_addr ),
    .data_sram_addr_ok      (data_sram_addr_ok),
    .data_sram_rdata        (data_sram_rdata),
    .data_sram_data_ok      (data_sram_data_ok_discard),
    .es_data_waiting        (es_data_waiting),
    // forward & block
    .es_fwd_blk_bus         (es_fwd_blk_bus ),
    //exception & block
    .ws_ex                  (ws_ex),
    .ws_eret                (ws_eret),
    .ms_ex                  (ms_ex),
    .ms_eret                (ms_eret),
    .es_inst_mfc0_o         (es_inst_mfc0)
);
// MEM stage
mem_stage mem_stage(
    .clk                    (aclk            ),
    .reset                  (reset          ),
    //allowin
    .ws_allowin             (ws_allowin     ),
    .ms_allowin             (ms_allowin     ),
    //from es
    .es_to_ms_valid         (es_to_ms_valid ),
    .es_to_ms_bus           (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid         (ms_to_ws_valid ),
    .ms_to_ws_bus           (ms_to_ws_bus   ),
    //to es
    .ms_inst_unable         (ms_inst_unable ),
    //from data-sram
    .data_sram_rdata        (data_sram_rdata),
    .data_sram_data_ok      (data_sram_data_ok_discard),
    .ms_data_waiting        (ms_data_waiting),
    // forward & block
    .ms_fwd_blk_bus         (ms_fwd_blk_bus),
    //exception & block
    .ws_ex                  (ws_ex),
    .ws_eret                (ws_eret),
    .ms_ex_o                (ms_ex),
    .ms_eret                (ms_eret),
    .ms_inst_mfc0_o         (ms_inst_mfc0)
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //exception & block
    .ws_ex_o        (ws_ex),
    .ws_eret        (ws_eret),
    .cp0_epc        (cp0_epc),
    .ws_inst_mfc0_o (ws_inst_mfc0),
    .ws_rf_dest     (ws_rf_dest),
    .cp0_cause      (cp0_cause),
    .cp0_status     (cp0_status)
);

transfer_bridge u_transfer_bridge(
    .aclk           (aclk               ),
    .aresetn        (aresetn            ),

    .arid           (arid               ),
    .araddr         (araddr             ),
    .arlen          (arlen              ),
    .arsize         (arsize             ),
    .arburst        (arburst            ),
    .arlock         (arlock             ),
    .arcache        (arcache            ),
    .arprot         (arprot             ),
    .arvalid        (arvalid            ),
    .arready        (arready            ),

    .rid            (rid                ),
    .rdata          (rdata              ),
    .rvalid         (rvalid             ),
    .rready         (rready             ),

    .awid           (awid               ),
    .awaddr         (awaddr             ),
    .awlen          (awlen              ),
    .awsize         (awsize             ),
    .awburst        (awburst            ),
    .awlock         (awlock             ),
    .awcache        (awcache            ),
    .awprot         (awprot             ),
    .awvalid        (awvalid            ),
    .awready        (awready            ),

    .wid            (wid                ),
    .wdata          (wdata              ),
    .wstrb          (wstrb              ),
    .wlast          (wlast              ),
    .wvalid         (wvalid             ),
    .wready         (wready             ),

    .bvalid         (bvalid             ),
    .bready         (bready             ),

    .inst_sram_req  (inst_sram_req      ),
    .inst_sram_wr   (inst_sram_wr       ),
    .inst_sram_size (inst_sram_size     ),
    .inst_sram_addr (inst_sram_addr     ),
    .inst_sram_wdata    (inst_sram_wdata),
    .inst_sram_rdata    (inst_sram_rdata),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),

    .data_sram_req  (data_sram_req      ),
    .data_sram_wr   (data_sram_wr       ),
    .data_sram_size (data_sram_size     ),
    .data_sram_addr (data_sram_addr     ),
    .data_sram_wdata    (data_sram_wdata),
    .data_sram_wstrb    (data_sram_wstrb),
    .data_sram_rdata    (data_sram_rdata),
    .data_sram_addr_ok  (data_sram_addr_ok),
    .data_sram_data_ok  (data_sram_data_ok)
);

endmodule
