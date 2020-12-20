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

    // tlb exception report
    input           tlb_refill,
    input           tlb_invalid,
    input           tlb_modified,

    // exception handle
    input           after_ex,
    input           do_flush,
    input   [31:0]  flush_pc
);

wire        to_pfs_valid;
reg         pfs_valid;
wire        pfs_allowin;
wire        pfs_ready_go;

wire        pfs_ex;
wire [31:0] pfs_badvaddr;
wire [ 4:0] pfs_excode;

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
assign to_pfs_valid     = ~reset && !pfs_ex && !after_ex;
assign pfs_allowin      = !pfs_valid || pfs_ready_go && fs_allowin;
assign pfs_ready_go     = pfs_addr_ok || pfs_ex;
assign pfs_to_fs_valid  = pfs_valid && pfs_ready_go && !do_flush;

assign pfs_to_fs_bus = {
    tlb_refill,     // 103
    pfs_inst_ok,    // 102:102
    pfs_inst,       // 101:70
    pfs_excode,     // 69:65
    pfs_badvaddr,   // 64:33
    pfs_ex,         // 32
    pfs_pc          // 31:0
};

always @ (posedge clk) begin
    if (reset) begin
        pfs_valid <= 1'b0;
    end else if (do_flush) begin
        pfs_valid <= 1'b1;
    end else if (pfs_allowin) begin
        pfs_valid <= to_pfs_valid;
    end
end

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
    end else if (target_leaving_pfs || do_flush) begin
        br_taken_r  <= 1'b0;
        br_target_r <= 32'h0;
    end else if (br_leaving_ds) begin
        br_taken_r  <= br_taken_w;
        br_target_r <= br_target_w;
    end

    if (reset) begin
        bd_done_r   <= 1'b0;
    end else if (target_leaving_pfs || do_flush) begin
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
    end else if (do_flush) begin
        seq_pc <= flush_pc;
    // end else if (ws_ex) begin
    //     if (ws_after_tlb) begin
    //         seq_pc <= after_tlb_pc;
    //     end else begin
    //         seq_pc <= `EX_ENTRY;
    //     end
    // end else if (ws_eret) begin
    //     seq_pc <= cp0_epc;
    end else if (pfs_ready_go && fs_allowin) begin
        seq_pc <= pfs_pc + 32'h4;
    end
end

assign pfs_pc = 
    (br_taken && bd_done)? br_target : seq_pc;

// ram control

assign inst_sram_req = 
    pfs_valid &&
    // fs_allowin &&
    !pfs_addr_ok_r && 
    !(bd_done && br_stall) && 
    !do_flush;
assign inst_sram_addr   = pfs_pc;
assign pfs_inst_waiting = pfs_addr_ok && !pfs_inst_ok;

assign pfs_inst_sram_data_ok = inst_sram_data_ok && fs_inst_unable;

always @ (posedge clk) begin
    if (reset) begin
        pfs_addr_ok_r <= 1'b0;
    end else if (do_flush) begin
        pfs_addr_ok_r <= 1'b0;
    end else if (inst_sram_req && inst_sram_addr_ok && !fs_allowin) begin
        pfs_addr_ok_r <= 1'b1;
    end else if (fs_allowin) begin
        pfs_addr_ok_r <= 1'b0;
    end
end
assign pfs_addr_ok  = (inst_sram_req && inst_sram_addr_ok) || pfs_addr_ok_r;

always @ (posedge clk) begin
    if (reset) begin
        pfs_inst_buff_valid <= 1'b0;
        pfs_inst_buff       <= 32'h0;
    end else if (fs_allowin || do_flush) begin
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


// exceptions
// exceptions are handled in here
wire addr_error;
assign addr_error = (pfs_pc[1:0] != 2'b0);

assign pfs_ex = pfs_valid && (tlb_refill || tlb_invalid || addr_error);
assign pfs_excode = 
    (addr_error                 )? `EX_ADEL :
    (tlb_refill || tlb_invalid  )? `EX_TLBL :
    `EX_NO;
assign pfs_badvaddr = inst_sram_addr;

endmodule