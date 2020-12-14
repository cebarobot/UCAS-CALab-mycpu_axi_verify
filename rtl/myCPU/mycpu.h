`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD           35

    `define PFS_TO_FS_BUS_WD    65
    `define FS_TO_DS_BUS_WD     97
    `define DS_TO_ES_BUS_WD     215
    `define ES_TO_MS_BUS_WD     172
    `define MS_TO_WS_BUS_WD     133
    `define WS_TO_RF_BUS_WD     41
    `define ES_FWD_BLK_BUS_WD   42
    `define MS_FWD_BLK_BUS_WD   42

    `define EX_INT              5'h00
    `define EX_ADEL             5'h04
    `define EX_ADES             5'h05
    `define EX_SYS              5'h08
    `define EX_BP               5'h09
    `define EX_RI               5'h0a
    `define EX_OV               5'h0c
    `define EX_NO               5'h1f

    `define EX_ENTRY            32'h_bfc00380

    `define CP0_BADV_ADDR       8'b01000000
    `define CP0_COUNT_ADDR      8'b01001000
    `define CP0_COMP_ADDR       8'b01011000
    `define CP0_STATUS_ADDR     8'b01100000
    `define CP0_CAUSE_ADDR      8'b01101000
    `define CP0_EPC_ADDR        8'b01110000
    `define CP0_CONFIG_ADDR     8'b10000000

    `define CP0_ENTRYHI_ADDR    8'b01010000
    `define CP0_ENTRYLO0_ADDR   8'b00010000
    `define CP0_ENTRYLO1_ADDR   8'b00011000
    `define CP0_INDEX_ADDR      8'b00000000

`endif
