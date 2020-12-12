`include "mycpu.h"
module mycpu_core(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [31:0] data_sram_addr,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

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

//tlb
// search port 0
wire  [              18:0] s0_vpn2;     
wire                       s0_odd_page;     
wire  [               7:0] s0_asid;     
wire                      s0_found;     
wire [                3:0] s0_index;   
wire [              19:0] s0_pfn;     
wire [               2:0] s0_c;     
wire                      s0_d;     
wire                      s0_v; 

// search port 1     
wire  [              18:0] s1_vpn2;     
wire                       s1_odd_page;     
wire  [               7:0] s1_asid;     
wire                      s1_found;     
wire [              3:0] s1_index;      
wire [              19:0] s1_pfn;     
wire [               2:0] s1_c;     
wire                      s1_d;     
wire                      s1_v; 

// write port
wire                       we;        
wire  [               3:0] w_index;     
wire  [              18:0] w_vpn2;     
wire  [               7:0] w_asid;     
wire                       w_g;     
wire  [              19:0] w_pfn0;     
wire  [               2:0] w_c0;     
wire                       w_d0;
wire                       w_v0;     
wire  [              19:0] w_pfn1;     
wire  [               2:0] w_c1;     
wire                       w_d1;     
wire                       w_v1;

// read port
wire  [               3:0] r_index;     
wire  [              18:0] r_vpn2;     
wire  [               7:0] r_asid;     
wire                       r_g;     
wire  [              19:0] r_pfn0;     
wire  [               2:0] r_c0;     
wire                       r_d0;
wire                       r_v0;     
wire  [              19:0] r_pfn1;     
wire  [               2:0] r_c1;     
wire                       r_d1;     
wire                       r_v1;


// inst_sram
assign inst_sram_wr     = 1'b0;
assign inst_sram_size   = 2'h2;
assign inst_sram_wstrb  = 4'h0;
assign inst_sram_wdata  = 32'h0;

wire        pfs_inst_waiting;
wire        fs_inst_waiting;
reg  [1:0]  inst_sram_discard;
wire        inst_sram_data_ok_discard;

always @ (posedge clk) begin
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

always @ (posedge clk) begin
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
    .clk                    (clk),
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
    .clk                    (clk),
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
    .clk            (clk            ),
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
    .clk                    (clk            ),
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
    .es_inst_mfc0_o         (es_inst_mfc0),
    //tlb-search1
    .s1_vpn2            (s1_vpn2),     
    .s1_odd_page        (s1_odd_page),     
    .s1_asid            (s1_asid),     
    .s1_found           (s1_found),     
    .s1_index           (s1_index),      
    .s1_pfn             (s1_pfn),     
    .s1_c               (s1_c),     
    .s1_d               (s1_d),     
    .s1_v               (s1_v),

    .ms_entryhi_block       (ms_entryhi_block), 
    .ws_entryhi_block   (ws_entryhi_block) 
);
// MEM stage
mem_stage mem_stage(
    .clk                    (clk            ),
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
    .ms_inst_mfc0_o         (ms_inst_mfc0),

    .ms_entryhi_block       (ms_entryhi_block) 
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
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
    .cp0_status     (cp0_status),
    //tlb
    // write port     
    .we                 (we),         
    .w_index            (w_index),     
    .w_vpn2             (w_vpn2),     
    .w_asid             (w_asid),     
    .w_g                (w_g),     
    .w_pfn0             (w_pfn0),     
    .w_c0               (w_c0),     
    .w_d0               (w_d0),
    .w_v0               (w_v0),     
    .w_pfn1             (w_pfn1),     
    .w_c1               (w_c1),     
    .w_d1               (w_d1),     
    .w_v1               (w_v1), 
    // read port 
    .r_index            (r_index),     
    .r_vpn2             (r_vpn2),     
    .r_asid             (r_asid),     
    .r_g                (r_g),     
    .r_pfn0             (r_pfn0),     
    .r_c0               (r_c0),     
    .r_d0               (r_d0),     
    .r_v0               (r_v0),     
    .r_pfn1             (r_pfn1),     
    .r_c1               (r_c1),     
    .r_d1               (r_d1),     
    .r_v1               (r_v1),

    .ws_entryhi_block   (ws_entryhi_block) 
);
//TLB 
tlb tlb(
    .clk                (clk),  
    // search port 0
    .s0_vpn2            (s0_vpn2),       
    .s0_odd_page        (s0_odd_page),     
    .s0_asid            (s0_asid),     
    .s0_found           (s0_found),     
    .s0_index           (s0_index),   
    .s0_pfn             (s0_pfn),     
    .s0_c               (s0_c),     
    .s0_d               (s0_d),     
    .s0_v               (s0_v), 
    // search port 1     
    .s1_vpn2            (s1_vpn2),     
    .s1_odd_page        (s1_odd_page),     
    .s1_asid            (s1_asid),     
    .s1_found           (s1_found),     
    .s1_index           (s1_index),      
    .s1_pfn             (s1_pfn),     
    .s1_c               (s1_c),     
    .s1_d               (s1_d),     
    .s1_v               (s1_v), 
    // write port     
    .we                 (we),         
    .w_index            (w_index),     
    .w_vpn2             (w_vpn2),     
    .w_asid             (w_asid),     
    .w_g                (w_g),     
    .w_pfn0             (w_pfn0),     
    .w_c0               (w_c0),     
    .w_d0               (w_d0),
    .w_v0               (w_v0),     
    .w_pfn1             (w_pfn1),     
    .w_c1               (w_c1),     
    .w_d1               (w_d1),     
    .w_v1               (w_v1), 
    // read port 
    .r_index            (r_index),     
    .r_vpn2             (r_vpn2),     
    .r_asid             (r_asid),     
    .r_g                (r_g),     
    .r_pfn0             (r_pfn0),     
    .r_c0               (r_c0),     
    .r_d0               (r_d0),     
    .r_v0               (r_v0),     
    .r_pfn1             (r_pfn1),     
    .r_c1               (r_c1),     
    .r_d1               (r_d1),     
    .r_v1               (r_v1)     
);
endmodule
