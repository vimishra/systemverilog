//==============================================================================
// Module: async_fifo_tb
// Description: Comprehensive testbench for async FIFO verification
//==============================================================================

`timescale 1ns/1ps

module async_fifo_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    parameter int DATA_WIDTH = 8;
    parameter int ADDR_WIDTH = 4;
    parameter int FIFO_DEPTH = 1 << ADDR_WIDTH;
    
    // Clock periods (different frequencies for async testing)
    parameter real WR_CLK_PERIOD = 10.0;  // 100 MHz
    parameter real RD_CLK_PERIOD = 15.0;  // 66.67 MHz
    
    //==========================================================================
    // DUT Signals
    //==========================================================================
    logic                  wr_clk;
    logic                  wr_rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  wr_full;
    
    logic                  rd_clk;
    logic                  rd_rst_n;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rd_empty;
    
    //==========================================================================
    // Testbench Variables
    //==========================================================================
    int test_num;
    int errors;
    int warnings;
    logic [DATA_WIDTH-1:0] write_data_queue[$];
    logic [DATA_WIDTH-1:0] read_data_queue[$];
    logic [DATA_WIDTH-1:0] expected_data;
    int writes_completed;
    int reads_completed;
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk    (wr_clk),
        .wr_rst_n  (wr_rst_n),
        .wr_en     (wr_en),
        .wr_data   (wr_data),
        .wr_full   (wr_full),
        .rd_clk    (rd_clk),
        .rd_rst_n  (rd_rst_n),
        .rd_en     (rd_en),
        .rd_data   (rd_data),
        .rd_empty  (rd_empty)
    );
    
    //==========================================================================
    // Assertions Binding (Icarus Verilog compatible)
    //==========================================================================
    // Note: Icarus Verilog has limited SVA support
    // For full assertion checking, use commercial simulators
    
    //==========================================================================
    // Clock Generation
    //==========================================================================
    initial begin
        wr_clk = 0;
        forever #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;
    end
    
    initial begin
        rd_clk = 0;
        forever #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;
    end
    
    //==========================================================================
    // Write Monitor - Track all writes
    //==========================================================================
    always @(posedge wr_clk) begin
        if (wr_rst_n && wr_en && !wr_full) begin
            write_data_queue.push_back(wr_data);
            writes_completed++;
            $display("[%0t] WRITE: Data=0x%0h, Queue_Size=%0d", 
                     $time, wr_data, write_data_queue.size());
        end
        
        if (wr_rst_n && wr_en && wr_full) begin
            warnings++;
            $display("[%0t] WARNING: Write attempted when FIFO full!", $time);
        end
    end
    
    //==========================================================================
    // Read Monitor - Track and verify all reads
    //==========================================================================
    always @(posedge rd_clk) begin
        if (rd_rst_n && rd_en && !rd_empty) begin
            read_data_queue.push_back(rd_data);
            reads_completed++;
            
            // Check data integrity
            if (write_data_queue.size() > 0) begin
                expected_data = write_data_queue.pop_front();
                if (rd_data !== expected_data) begin
                    errors++;
                    $display("[%0t] ERROR: DATA MISMATCH! Expected=0x%0h, Got=0x%0h", 
                           $time, expected_data, rd_data);
                end else begin
                    $display("[%0t] READ:  Data=0x%0h (MATCH), Queue_Size=%0d", 
                             $time, rd_data, write_data_queue.size());
                end
            end
        end
        
        if (rd_rst_n && rd_en && rd_empty) begin
            warnings++;
            $display("[%0t] WARNING: Read attempted when FIFO empty!", $time);
        end
    end
    
    //==========================================================================
    // Test Stimulus
    //==========================================================================
    initial begin
        // Initialize
        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        test_num = 0;
        errors = 0;
        warnings = 0;
        writes_completed = 0;
        reads_completed = 0;
        
        // Waveform dump for Icarus Verilog
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);
        
        // Release resets
        #(WR_CLK_PERIOD * 5);
        wr_rst_n = 1;
        rd_rst_n = 1;
        #(WR_CLK_PERIOD * 2);
        
        $display("\n========================================");
        $display("Starting Async FIFO Test Suite");
        $display("FIFO Depth: %0d", FIFO_DEPTH);
        $display("Data Width: %0d", DATA_WIDTH);
        $display("========================================\n");
        
        // Run all test cases
        run_test_01_basic_write_read();
        run_test_02_full_fifo();
        run_test_03_empty_fifo();
        run_test_04_simultaneous_wr_rd();
        run_test_05_burst_write_then_read();
        run_test_06_alternating_wr_rd();
        run_test_07_random_traffic();
        run_test_08_clock_ratio_stress();
        run_test_09_reset_during_operation();
        run_test_10_corner_cases();
        
        // Final Report
        #(WR_CLK_PERIOD * 100);
        print_final_report();
        
        $finish;
    end
    
    //==========================================================================
    // TEST CASE 01: Basic Write and Read
    // Objective: Verify single write followed by single read
    //==========================================================================
    task run_test_01_basic_write_read();
        test_num++;
        $display("\n[TEST_%0d] Basic Write and Read", test_num);
        $display("Objective: Single write followed by single read");
        
        // Write one data item
        @(posedge wr_clk);
        wr_en = 1;
        wr_data = 8'hA5;
        @(posedge wr_clk);
        wr_en = 0;
        
        // Wait for synchronization
        repeat(10) @(posedge rd_clk);
        
        // Read one data item
        @(posedge rd_clk);
        rd_en = 1;
        @(posedge rd_clk);
        rd_en = 0;
        
        repeat(10) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 02: Fill FIFO Completely
    // Objective: Verify full flag assertion and prevention of overwrites
    //==========================================================================
    task run_test_02_full_fifo();
        int i;
        test_num++;
        $display("\n[TEST_%0d] Fill FIFO to Full", test_num);
        $display("Objective: Verify full flag and no overwrites");
        
        // Write until full
        i = 0;
        while (i < FIFO_DEPTH && !wr_full) begin
            @(posedge wr_clk);
            if (!wr_full) begin
                wr_en = 1;
                wr_data = i[DATA_WIDTH-1:0];
                i = i + 1;
            end
        end
        
        @(posedge wr_clk);
        wr_en = 0;
        $display("FIFO filled with %0d entries", i);
        
        // Try to write when full (should be prevented)
        repeat(5) @(posedge wr_clk);
        if (wr_full) begin
            $display("Attempting write to full FIFO (should generate warning)");
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = 8'hFF;
            @(posedge wr_clk);
            wr_en = 0;
        end
        
        repeat(10) @(posedge wr_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 03: Empty FIFO Read
    // Objective: Verify empty flag and prevention of underflow
    //==========================================================================
    task run_test_03_empty_fifo();
        test_num++;
        $display("\n[TEST_%0d] Empty FIFO Read Attempt", test_num);
        $display("Objective: Verify empty flag and no underflow");
        
        // First, drain any remaining data from previous tests
        while (!rd_empty) begin
            @(posedge rd_clk);
            rd_en = 1;
        end
        @(posedge rd_clk);
        rd_en = 0;
        
        // Wait for empty to stabilize
        repeat(10) @(posedge rd_clk);
        
        // Try to read from empty FIFO
        if (rd_empty) begin
            $display("Attempting read from empty FIFO (should generate warning)");
            @(posedge rd_clk);
            rd_en = 1;
            @(posedge rd_clk);
            rd_en = 0;
        end
        
        repeat(10) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 04: Simultaneous Write and Read
    // Objective: Verify concurrent operations at different clock rates
    //==========================================================================
    task run_test_04_simultaneous_wr_rd();
        test_num++;
        $display("\n[TEST_%0d] Simultaneous Write and Read", test_num);
        $display("Objective: Concurrent operations with async clocks");
        
        fork
            // Writer process
            begin
                for (int i = 0; i < 20; i++) begin
                    @(posedge wr_clk);
                    if (!wr_full) begin
                        wr_en = 1;
                        wr_data = $random;
                    end else begin
                        wr_en = 0;
                    end
                end
                @(posedge wr_clk);
                wr_en = 0;
            end
            
            // Reader process
            begin
                repeat(5) @(posedge rd_clk);  // Delay read start
                for (int i = 0; i < 20; i++) begin
                    @(posedge rd_clk);
                    if (!rd_empty) begin
                        rd_en = 1;
                    end else begin
                        rd_en = 0;
                    end
                end
                @(posedge rd_clk);
                rd_en = 0;
            end
        join
        
        repeat(20) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 05: Burst Write Then Burst Read
    // Objective: Write multiple entries, then read them all back
    //==========================================================================
    task run_test_05_burst_write_then_read();
        test_num++;
        $display("\n[TEST_%0d] Burst Write Then Burst Read", test_num);
        $display("Objective: Sequential burst operations");
        
        // Burst write
        for (int i = 0; i < FIFO_DEPTH-1; i++) begin
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = 8'h10 + i;
        end
        @(posedge wr_clk);
        wr_en = 0;
        
        // Wait for synchronization
        repeat(15) @(posedge rd_clk);
        
        // Burst read
        while (!rd_empty) begin
            @(posedge rd_clk);
            rd_en = 1;
        end
        @(posedge rd_clk);
        rd_en = 0;
        
        repeat(10) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 06: Alternating Write/Read
    // Objective: Write one, read one, repeat
    //==========================================================================
    task run_test_06_alternating_wr_rd();
        test_num++;
        $display("\n[TEST_%0d] Alternating Write/Read", test_num);
        $display("Objective: Single write, single read pattern");
        
        for (int i = 0; i < 10; i++) begin
            // Write
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = 8'h20 + i;
            @(posedge wr_clk);
            wr_en = 0;
            
            // Wait for data to propagate
            repeat(10) @(posedge rd_clk);
            
            // Read
            @(posedge rd_clk);
            rd_en = 1;
            @(posedge rd_clk);
            rd_en = 0;
            
            repeat(5) @(posedge rd_clk);
        end
        
        repeat(10) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 07: Random Traffic Pattern
    // Objective: Random write/read enables to stress FIFO
    //==========================================================================
    task run_test_07_random_traffic();
        test_num++;
        $display("\n[TEST_%0d] Random Traffic Pattern", test_num);
        $display("Objective: Stress test with random operations");
        
        fork
            // Random writer
            begin
                for (int i = 0; i < 50; i++) begin
                    @(posedge wr_clk);
                    if ($random % 2 && !wr_full) begin
                        wr_en = 1;
                        wr_data = $random;
                    end else begin
                        wr_en = 0;
                    end
                end
                @(posedge wr_clk);
                wr_en = 0;
            end
            
            // Random reader
            begin
                for (int i = 0; i < 50; i++) begin
                    @(posedge rd_clk);
                    if ($random % 2 && !rd_empty) begin
                        rd_en = 1;
                    end else begin
                        rd_en = 0;
                    end
                end
                @(posedge rd_clk);
                rd_en = 0;
            end
        join
        
        // Drain remaining data
        while (!rd_empty) begin
            @(posedge rd_clk);
            rd_en = 1;
        end
        @(posedge rd_clk);
        rd_en = 0;
        
        repeat(20) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 08: Clock Ratio Stress
    // Objective: Sustained traffic with different clock frequencies
    //==========================================================================
    task run_test_08_clock_ratio_stress();
        test_num++;
        $display("\n[TEST_%0d] Clock Ratio Stress Test", test_num);
        $display("Objective: Verify CDC with frequency mismatch");
        
        fork
            // Continuous writer
            begin
                for (int i = 0; i < 100; i++) begin
                    @(posedge wr_clk);
                    if (!wr_full) begin
                        wr_en = 1;
                        wr_data = i[DATA_WIDTH-1:0];
                    end else begin
                        wr_en = 0;
                    end
                end
                @(posedge wr_clk);
                wr_en = 0;
            end
            
            // Continuous reader
            begin
                for (int i = 0; i < 120; i++) begin
                    @(posedge rd_clk);
                    if (!rd_empty) begin
                        rd_en = 1;
                    end else begin
                        rd_en = 0;
                    end
                end
                @(posedge rd_clk);
                rd_en = 0;
            end
        join
        
        repeat(30) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 09: Reset During Operation
    // Objective: Verify clean reset recovery
    //==========================================================================
    task run_test_09_reset_during_operation();
        test_num++;
        $display("\n[TEST_%0d] Reset During Operation", test_num);
        $display("Objective: Verify reset clears FIFO state");
        
        // Fill FIFO partially
        for (int i = 0; i < FIFO_DEPTH/2; i++) begin
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = 8'hAA;
        end
        @(posedge wr_clk);
        wr_en = 0;
        
        // Assert write reset
        repeat(3) @(posedge wr_clk);
        wr_rst_n = 0;
        repeat(5) @(posedge wr_clk);
        wr_rst_n = 1;
        
        // Assert read reset
        repeat(3) @(posedge rd_clk);
        rd_rst_n = 0;
        repeat(5) @(posedge rd_clk);
        rd_rst_n = 1;
        
        // Verify FIFO is empty after reset
        repeat(10) @(posedge rd_clk);
        if (!rd_empty) begin
            errors++;
            $display("[%0t] ERROR: FIFO not empty after reset!", $time);
        end else begin
            $display("FIFO correctly empty after reset");
        end
        
        // Clear the queue since reset invalidates data
        write_data_queue.delete();
        
        repeat(10) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // TEST CASE 10: Corner Cases
    // Objective: Test wrap-around and boundary conditions
    //==========================================================================
    task run_test_10_corner_cases();
        test_num++;
        $display("\n[TEST_%0d] Corner Cases", test_num);
        $display("Objective: Wrap-around and boundary conditions");
        
        // Test 1: Fill, read one, write one (tests almost full)
        $display("  Sub-test: Almost full condition");
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            @(posedge wr_clk);
            wr_en = 1;
            wr_data = i[DATA_WIDTH-1:0];
        end
        @(posedge wr_clk);
        wr_en = 0;
        
        repeat(15) @(posedge rd_clk);
        @(posedge rd_clk);
        rd_en = 1;
        @(posedge rd_clk);
        rd_en = 0;
        
        repeat(10) @(posedge wr_clk);
        @(posedge wr_clk);
        wr_en = 1;
        wr_data = 8'hBB;
        @(posedge wr_clk);
        wr_en = 0;
        
        // Drain FIFO
        repeat(15) @(posedge rd_clk);
        while (!rd_empty) begin
            @(posedge rd_clk);
            rd_en = 1;
        end
        @(posedge rd_clk);
        rd_en = 0;
        
        // Test 2: Multiple wrap-arounds
        $display("  Sub-test: Multiple wrap-arounds");
        fork
            begin
                for (int i = 0; i < FIFO_DEPTH * 3; i++) begin
                    @(posedge wr_clk);
                    if (!wr_full) begin
                        wr_en = 1;
                        wr_data = i[DATA_WIDTH-1:0];
                    end else begin
                        wr_en = 0;
                    end
                end
                @(posedge wr_clk);
                wr_en = 0;
            end
            
            begin
                repeat(10) @(posedge rd_clk);
                for (int i = 0; i < FIFO_DEPTH * 3; i++) begin
                    @(posedge rd_clk);
                    if (!rd_empty) begin
                        rd_en = 1;
                    end else begin
                        rd_en = 0;
                    end
                end
                @(posedge rd_clk);
                rd_en = 0;
            end
        join
        
        repeat(20) @(posedge rd_clk);
        $display("[TEST_%0d] COMPLETED\n", test_num);
    endtask
    
    //==========================================================================
    // Final Report
    //==========================================================================
    task print_final_report();
        $display("\n========================================");
        $display("ASYNC FIFO TEST SUITE COMPLETED");
        $display("========================================");
        $display("Tests Run:         %0d", test_num);
        $display("Writes Completed:  %0d", writes_completed);
        $display("Reads Completed:   %0d", reads_completed);
        $display("Errors:            %0d", errors);
        $display("Warnings:          %0d", warnings);
        $display("Pending Data:      %0d", write_data_queue.size());
        
        if (errors == 0 && write_data_queue.size() == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
        end else begin
            $display("\n*** TESTS FAILED ***");
            if (write_data_queue.size() > 0) begin
                $display("WARNING: %0d items still in queue", write_data_queue.size());
            end
        end
        $display("========================================\n");
    endtask

endmodule
