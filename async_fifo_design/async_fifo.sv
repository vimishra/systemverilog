//==============================================================================
// Module: async_fifo
// Description: Parameterized Asynchronous FIFO for safe clock domain crossing
//
// Theory of Operation:
// -------------------
// The async FIFO uses Gray-coded pointers to safely cross clock domains.
// Key principles:
//   1. Write pointer increments in write clock domain
//   2. Read pointer increments in read clock domain
//   3. Pointers are converted to Gray code before synchronization
//   4. Gray code ensures only 1 bit changes at a time (CDC-safe)
//   5. Synchronized pointers are compared to generate full/empty flags
//
// FULL Logic (in write clock domain):
//   - Full when write pointer (next) equals synchronized read pointer
//   - AND MSBs differ (indicating wrap-around difference)
//   - Extra pointer bit distinguishes full from empty condition
//
// EMPTY Logic (in read clock domain):
//   - Empty when read pointer equals synchronized write pointer
//   - All bits match (including MSB)
//
// Parameters:
//   DATA_WIDTH - Width of data bus
//   ADDR_WIDTH - Address width (FIFO depth = 2^ADDR_WIDTH)
//
// CDC Safety:
//   - All pointers synchronized with 2-stage synchronizers
//   - Gray code encoding prevents metastability issues
//   - Full/empty flags generated in respective clock domains
//==============================================================================

module async_fifo #(
    parameter int DATA_WIDTH = 8,    // Data bus width
    parameter int ADDR_WIDTH = 4     // Address width (depth = 2^ADDR_WIDTH)
) (
    // Write clock domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  wr_full,
    
    // Read clock domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_empty
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    localparam int FIFO_DEPTH = 1 << ADDR_WIDTH;
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;  // Extra bit for full/empty distinction
    
    //==========================================================================
    // Internal Signals - Write Clock Domain
    //==========================================================================
    logic [PTR_WIDTH-1:0] wr_ptr_bin;           // Binary write pointer
    logic [PTR_WIDTH-1:0] wr_ptr_gray;          // Gray-coded write pointer
    logic [PTR_WIDTH-1:0] wr_ptr_gray_next;     // Next Gray write pointer
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync;     // Synchronized read pointer (Gray)
    logic [PTR_WIDTH-1:0] rd_ptr_bin_sync;      // Synchronized read pointer (Binary)
    
    //==========================================================================
    // Internal Signals - Read Clock Domain
    //==========================================================================
    logic [PTR_WIDTH-1:0] rd_ptr_bin;           // Binary read pointer
    logic [PTR_WIDTH-1:0] rd_ptr_gray;          // Gray-coded read pointer
    logic [PTR_WIDTH-1:0] rd_ptr_gray_next;     // Next Gray read pointer
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync;     // Synchronized write pointer (Gray)
    logic [PTR_WIDTH-1:0] wr_ptr_bin_sync;      // Synchronized write pointer (Binary)
    
    //==========================================================================
    // Memory Array
    //==========================================================================
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    
    //==========================================================================
    // Write Clock Domain Logic
    //==========================================================================
    
    // Write pointer increment (binary)
    // Only increment when write is enabled and FIFO is not full
    logic wr_ptr_inc;
    assign wr_ptr_inc = wr_en & ~wr_full;
    
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin <= '0;
        end else if (wr_ptr_inc) begin
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
        end
    end
    
    // Convert binary write pointer to Gray code
    // Gray code formula: gray = binary ^ (binary >> 1)
    // This ensures only one bit changes during increment
    assign wr_ptr_gray = bin_to_gray(wr_ptr_bin);
    assign wr_ptr_gray_next = bin_to_gray(wr_ptr_bin + 1'b1);
    
    // Memory write operation
    always_ff @(posedge wr_clk) begin
        if (wr_ptr_inc) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end
    
    //==========================================================================
    // FULL Generation Logic (Write Clock Domain)
    //==========================================================================
    // FULL Condition:
    //   The FIFO is full when the write pointer (next value) would equal
    //   the synchronized read pointer, BUT with the MSB inverted.
    //
    // Why MSB differs:
    //   - When write pointer wraps around and catches read pointer,
    //     the MSB difference indicates the write has lapped the read
    //   - This distinguishes full (ptrs equal but MSB diff) from 
    //     empty (ptrs completely equal)
    //
    // Example with 3-bit pointers (4 locations):
    //   Empty: wr=000, rd=000 (all bits match)
    //   Full:  wr=100, rd=000 (MSB differs, lower bits match)
    //==========================================================================
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_full <= 1'b0;
        end else begin
            // Check if next write pointer will cause full condition
            wr_full <= (wr_ptr_gray_next == {~rd_ptr_gray_sync[PTR_WIDTH-1], 
                                             rd_ptr_gray_sync[PTR_WIDTH-2:0]});
        end
    end
    
    //==========================================================================
    // Read Clock Domain Logic
    //==========================================================================
    
    // Read pointer increment (binary)
    // Only increment when read is enabled and FIFO is not empty
    logic rd_ptr_inc;
    assign rd_ptr_inc = rd_en & ~rd_empty;
    
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin <= '0;
        end else if (rd_ptr_inc) begin
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
        end
    end
    
    // Convert binary read pointer to Gray code
    assign rd_ptr_gray = bin_to_gray(rd_ptr_bin);
    assign rd_ptr_gray_next = bin_to_gray(rd_ptr_bin + 1'b1);
    
    // Memory read operation
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
    
    //==========================================================================
    // EMPTY Generation Logic (Read Clock Domain)
    //==========================================================================
    // EMPTY Condition:
    //   The FIFO is empty when the read pointer equals the synchronized
    //   write pointer exactly (all bits match, including MSB).
    //
    // Why all bits must match:
    //   - When read catches up to write, all pointer bits are identical
    //   - No data available to read
    //   - Different from full where MSBs differ
    //
    // Example with 3-bit pointers:
    //   Empty: rd=010, wr_sync=010 (all bits identical)
    //   Not Empty: rd=010, wr_sync=011 or 110, etc.
    //==========================================================================
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_empty <= 1'b1;  // FIFO starts empty
        end else begin
            // Check if next read pointer will cause empty condition
            rd_empty <= (rd_ptr_gray_next == wr_ptr_gray_sync);
        end
    end
    
    //==========================================================================
    // Clock Domain Crossing Synchronizers
    //==========================================================================
    // 2-Stage Synchronizers for CDC Safety
    // Gray code ensures only 1 bit changes, reducing metastability risk
    
    // Synchronize write pointer to read clock domain
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync_stage1;
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync_stage1 <= '0;
            wr_ptr_gray_sync        <= '0;
        end else begin
            wr_ptr_gray_sync_stage1 <= wr_ptr_gray;
            wr_ptr_gray_sync        <= wr_ptr_gray_sync_stage1;
        end
    end
    
    // Synchronize read pointer to write clock domain
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync_stage1;
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync_stage1 <= '0;
            rd_ptr_gray_sync        <= '0;
        end else begin
            rd_ptr_gray_sync_stage1 <= rd_ptr_gray;
            rd_ptr_gray_sync        <= rd_ptr_gray_sync_stage1;
        end
    end
    
    //==========================================================================
    // Binary to Gray Code Conversion Function
    //==========================================================================
    // Gray Code Properties:
    //   - Only one bit changes between consecutive values
    //   - Prevents multi-bit transitions during CDC
    //   - Formula: gray[i] = binary[i] ^ binary[i+1]
    //   - MSB remains unchanged: gray[MSB] = binary[MSB]
    //
    // Example Conversions (4-bit):
    //   Binary  -> Gray
    //   0000    -> 0000
    //   0001    -> 0001
    //   0010    -> 0011
    //   0011    -> 0010
    //   0100    -> 0110
    //   ...
    //
    // Why it works for CDC:
    //   - Single bit transition means only one flop can go metastable
    //   - Other bits remain stable during sampling
    //   - Reduces probability of incorrect value capture
    //==========================================================================
    function automatic logic [PTR_WIDTH-1:0] bin_to_gray(
        input logic [PTR_WIDTH-1:0] binary
    );
        logic [PTR_WIDTH-1:0] gray;
        
        // MSB stays the same
        gray[PTR_WIDTH-1] = binary[PTR_WIDTH-1];
        
        // Each other bit is XOR of current and next higher bit
        for (int i = 0; i < PTR_WIDTH-1; i++) begin
            gray[i] = binary[i] ^ binary[i+1];
        end
        
        return gray;
    endfunction
    
    //==========================================================================
    // Gray to Binary Code Conversion Function (for debugging/analysis)
    //==========================================================================
    // Reverse conversion - useful for testbench monitoring
    // Formula: binary[i] = XOR of all gray bits from MSB to i
    //==========================================================================
    function automatic logic [PTR_WIDTH-1:0] gray_to_bin(
        input logic [PTR_WIDTH-1:0] gray
    );
        logic [PTR_WIDTH-1:0] binary;
        
        binary[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
        
        for (int i = PTR_WIDTH-2; i >= 0; i--) begin
            binary[i] = binary[i+1] ^ gray[i];
        end
        
        return binary;
    endfunction
    
    // Convert synchronized Gray pointers to binary for analysis
    assign wr_ptr_bin_sync = gray_to_bin(wr_ptr_gray_sync);
    assign rd_ptr_bin_sync = gray_to_bin(rd_ptr_gray_sync);

endmodule
