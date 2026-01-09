//==============================================================================
// Module: async_fifo_assertions
// Description: Comprehensive assertions for async FIFO verification
//==============================================================================

module async_fifo_assertions #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
) (
    input logic                  wr_clk,
    input logic                  wr_rst_n,
    input logic                  wr_en,
    input logic [DATA_WIDTH-1:0] wr_data,
    input logic                  wr_full,
    
    input logic                  rd_clk,
    input logic                  rd_rst_n,
    input logic                  rd_en,
    input logic [DATA_WIDTH-1:0] rd_data,
    input logic                  rd_empty
);

    localparam int PTR_WIDTH = ADDR_WIDTH + 1;
    
    //==========================================================================
    // Write Clock Domain Assertions
    //==========================================================================
    
    // AST_WR_01: Write enable should not be asserted when FIFO is full
    property p_no_write_when_full;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        wr_full |-> !wr_en;
    endproperty
    ast_wr_01_no_write_when_full: assert property (p_no_write_when_full)
        else $error("[AST_WR_01] Write attempted when FIFO is full!");
    
    // AST_WR_02: Full flag should remain stable until a read occurs
    // (Note: This checks across domains, so it's a soft check)
    property p_full_stable_until_read;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $rose(wr_full) |-> wr_full throughout (##1 !wr_full[->1]);
    endproperty
    ast_wr_02_full_stable: assert property (p_full_stable_until_read)
        else $warning("[AST_WR_02] Full flag unstable without read");
    
    // AST_WR_03: Full flag must deassert eventually after write stops
    // (Assumes reads are occurring)
    property p_full_eventually_clears;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        wr_full && !wr_en |-> ##[1:100] !wr_full;
    endproperty
    ast_wr_03_full_clears: assert property (p_full_eventually_clears)
        else $warning("[AST_WR_03] Full flag stuck - reads may have stopped");
    
    // AST_WR_04: After reset, full should be deasserted
    property p_full_after_reset;
        @(posedge wr_clk)
        !wr_rst_n |=> !wr_full;
    endproperty
    ast_wr_04_full_after_reset: assert property (p_full_after_reset)
        else $error("[AST_WR_04] Full asserted immediately after reset!");
    
    //==========================================================================
    // Read Clock Domain Assertions
    //==========================================================================
    
    // AST_RD_01: Read enable should not be asserted when FIFO is empty
    property p_no_read_when_empty;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        rd_empty |-> !rd_en;
    endproperty
    ast_rd_01_no_read_when_empty: assert property (p_no_read_when_empty)
        else $error("[AST_RD_01] Read attempted when FIFO is empty!");
    
    // AST_RD_02: After reset, empty should be asserted
    property p_empty_after_reset;
        @(posedge rd_clk)
        !rd_rst_n |=> rd_empty;
    endproperty
    ast_rd_02_empty_after_reset: assert property (p_empty_after_reset)
        else $error("[AST_RD_02] Empty not asserted after reset!");
    
    // AST_RD_03: Empty flag should remain stable until a write occurs
    property p_empty_stable_until_write;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $rose(rd_empty) |-> rd_empty throughout (##1 !rd_empty[->1]);
    endproperty
    ast_rd_03_empty_stable: assert property (p_empty_stable_until_write)
        else $warning("[AST_RD_03] Empty flag unstable without write");
    
    // AST_RD_04: Empty flag must deassert eventually after read stops
    // (Assumes writes are occurring)
    property p_empty_eventually_clears;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        rd_empty && !rd_en |-> ##[1:100] !rd_empty;
    endproperty
    ast_rd_04_empty_clears: assert property (p_empty_eventually_clears)
        else $warning("[AST_RD_04] Empty flag stuck - writes may have stopped");
    
    //==========================================================================
    // Cross-Domain Assertions (Timing-relaxed)
    //==========================================================================
    
    // AST_CD_01: FIFO cannot be both full and empty simultaneously
    // (Check in both domains with some timing slack)
    property p_not_full_and_empty_wr;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        !(wr_full && rd_empty);
    endproperty
    ast_cd_01a_not_full_and_empty: assert property (p_not_full_and_empty_wr)
        else $error("[AST_CD_01] FIFO is both full and empty (wr_clk)!");
    
    property p_not_full_and_empty_rd;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        !(wr_full && rd_empty);
    endproperty
    ast_cd_01b_not_full_and_empty: assert property (p_not_full_and_empty_rd)
        else $error("[AST_CD_01] FIFO is both full and empty (rd_clk)!");
    
    //==========================================================================
    // Data Integrity Assertions (for testbench use)
    //==========================================================================
    
    // AST_DI_01: Cover property - successful write
    property p_cover_write;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        wr_en && !wr_full;
    endproperty
    cov_write_success: cover property (p_cover_write);
    
    // AST_DI_02: Cover property - successful read
    property p_cover_read;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        rd_en && !rd_empty;
    endproperty
    cov_read_success: cover property (p_cover_read);
    
    // AST_DI_03: Cover property - FIFO full condition reached
    property p_cover_full;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $rose(wr_full);
    endproperty
    cov_full_reached: cover property (p_cover_full);
    
    // AST_DI_04: Cover property - FIFO empty condition reached
    property p_cover_empty;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $rose(rd_empty);
    endproperty
    cov_empty_reached: cover property (p_cover_empty);
    
    // AST_DI_05: Cover property - back-to-back writes
    property p_cover_back_to_back_writes;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        (wr_en && !wr_full) ##1 (wr_en && !wr_full);
    endproperty
    cov_back_to_back_writes: cover property (p_cover_back_to_back_writes);
    
    // AST_DI_06: Cover property - back-to-back reads
    property p_cover_back_to_back_reads;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        (rd_en && !rd_empty) ##1 (rd_en && !rd_empty);
    endproperty
    cov_back_to_back_reads: cover property (p_cover_back_to_back_reads);

endmodule
