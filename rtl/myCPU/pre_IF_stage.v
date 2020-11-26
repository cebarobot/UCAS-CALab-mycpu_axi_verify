`include "mycpu.h"

module pre_if_stage(        // instruction require stage
    input   clk,
    input   reset,
    // from fs
    input                               fs_allowin,
    // to fs
    output                              pfs_to_fs_valid,
    output  [`PFS_TO_FS_BUS_WD - 1:0]   pfs_to_fs_bus,

    // from fs
    input                               fs_inst_unable,

    // br_bus
    input   [`BR_BUS_WD - 1:0]          br_bus,
    input                               fs_valid,

    // inst_ram interface
    output          inst_sram_req,
    output  [31:0]  inst_sram_addr,
    input           inst_sram_addr_ok,
    input   [31:0]  inst_sram_rdata,
    input           inst_sram_data_ok,
    output          pfs_inst_waiting, 

    // exception
    input           ws_eret,
    input           ws_ex,
    input   [31:0]  cp0_epc
);

wire        pfs_valid;       // ? Is this needed?
wire        pfs_ready_go;

// br_bus
wire        br_leaving_ds;
wire        br_stall;

wire        br_taken_w;
wire [31:0] br_target_w;
wire        bd_done_w;

reg         br_taken_r;
reg  [31:0] br_target_r;
reg         bd_done_r;

wire        br_taken;
wire [31:0] br_target;
wire        bd_done;

// pc
reg  [31:0] seq_pc;
wire [31:0] pfs_pc;

// ram
reg         pfs_addr_ok_r;
wire        pfs_addr_ok;

reg         pfs_inst_buff_valid;
reg  [31:0] pfs_inst_buff;
wire        pfs_inst_ok;
wire [31:0] pfs_inst;

wire        pfs_inst_sram_data_ok;

// between stage 
assign pfs_valid        = ~reset;
assign pfs_ready_go     = pfs_addr_ok;
assign pfs_to_fs_valid  = pfs_valid && pfs_ready_go && !ws_eret && !ws_ex;

assign pfs_to_fs_bus = {
    pfs_inst_ok,    // 64:64
    pfs_inst,       // 63:32
    pfs_pc          // 31:0
};

// branch control
assign {
    br_leaving_ds,
    br_stall,
    br_taken_w,
    br_target_w
} = br_bus;
assign bd_done_w = fs_valid;

wire   target_leaving_pfs;
assign target_leaving_pfs = br_taken && pfs_to_fs_valid && fs_allowin && bd_done;
wire   bd_leaving_pfs;
assign bd_leaving_pfs = br_taken && pfs_to_fs_valid && fs_allowin && !bd_done;

always @ (posedge clk) begin
    if (reset) begin
        br_taken_r  <= 1'b0;
        br_target_r <= 32'h0;
    end else if (target_leaving_pfs || ws_eret || ws_ex) begin
        br_taken_r  <= 1'b0;
        br_target_r <= 32'h0;
    end else if (br_leaving_ds) begin
        br_taken_r  <= br_taken_w;
        br_target_r <= br_target_w;
    end

    if (reset) begin
        bd_done_r   <= 1'b0;
    end else if (target_leaving_pfs || ws_eret || ws_ex) begin
        bd_done_r   <= 1'b0;
    end else if (br_leaving_ds) begin
        bd_done_r   <= fs_valid || (pfs_to_fs_valid && fs_allowin);
    end else if (bd_leaving_pfs) begin
        bd_done_r   <= 1'b1;
    end
end

assign br_taken     = br_taken_r || br_taken_w;
assign br_target    = br_taken_r ? br_target_r : br_target_w;
assign bd_done      = bd_done_r || bd_done_w;

// pc control
always @ (posedge clk) begin
    if (reset) begin
        seq_pc <= 32'h_bfc00000;
    end else if (ws_ex) begin
        seq_pc <= `EX_ENTRY;
    end else if (ws_eret) begin
        seq_pc <= cp0_epc;
    end else if (pfs_ready_go && fs_allowin) begin
        seq_pc <= pfs_pc + 32'h4;
    end
end

assign pfs_pc = 
    br_taken && bd_done ?   br_target   :
    seq_pc;

// ram control

assign inst_sram_req = 
    pfs_valid &&
    // fs_allowin &&
    !pfs_addr_ok_r && 
    !(bd_done && br_stall) && 
    !ws_eret && !ws_ex;
assign inst_sram_addr   = {pfs_pc[31:2], 2'b0};
assign pfs_inst_waiting = pfs_addr_ok && !pfs_inst_ok;

assign pfs_inst_sram_data_ok = inst_sram_data_ok && fs_inst_unable;

always @ (posedge clk) begin
    if (reset) begin
        pfs_addr_ok_r <= 1'b0;
    end else if (inst_sram_req && inst_sram_addr_ok && !fs_allowin) begin
        pfs_addr_ok_r <= 1'b1;
    end else if (fs_allowin || ws_eret || ws_ex) begin
        pfs_addr_ok_r <= 1'b0;
    end
end
assign pfs_addr_ok  = (inst_sram_req && inst_sram_addr_ok) || pfs_addr_ok_r;

always @ (posedge clk) begin
    if (reset) begin
        pfs_inst_buff_valid <= 1'b0;
        pfs_inst_buff       <= 32'h0;
    end else if (fs_allowin || ws_eret || ws_ex) begin
        pfs_inst_buff_valid <= 1'b0;
        pfs_inst_buff       <= 32'h0;
    end else if (pfs_addr_ok && pfs_inst_sram_data_ok && !fs_allowin) begin
        pfs_inst_buff_valid <= 1'b1;
        pfs_inst_buff       <= inst_sram_rdata;
    end
end

assign pfs_inst_ok  = pfs_inst_buff_valid || (pfs_addr_ok && pfs_inst_sram_data_ok);
assign pfs_inst = 
    pfs_inst_buff_valid ?   pfs_inst_buff :
    inst_sram_rdata;


// exceptions are handled in if_stage

endmodule