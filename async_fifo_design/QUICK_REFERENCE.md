# Async FIFO Quick Reference Guide

## Design Parameters
```systemverilog
parameter int DATA_WIDTH = 8;    // Data bus width (1-1024)
parameter int ADDR_WIDTH = 4;    // Address width (2-16)
// FIFO_DEPTH = 2^ADDR_WIDTH
```

## Instantiation Template
```systemverilog
async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(4)
) u_fifo (
    // Write side
    .wr_clk    (wr_clk),
    .wr_rst_n  (wr_rst_n),
    .wr_en     (wr_en),
    .wr_data   (wr_data),
    .wr_full   (wr_full),
    
    // Read side
    .rd_clk    (rd_clk),
    .rd_rst_n  (rd_rst_n),
    .rd_en     (rd_en),
    .rd_data   (rd_data),
    .rd_empty  (rd_empty)
);
```

## Write Operation
```systemverilog
// Check if FIFO can accept data
if (!wr_full) begin
    wr_en   = 1'b1;
    wr_data = <your_data>;
end else begin
    wr_en = 1'b0;
    // Handle full condition
end
```

## Read Operation
```systemverilog
// Check if FIFO has data
if (!rd_empty) begin
    rd_en = 1'b1;
    // rd_data will be valid on next clock cycle
end else begin
    rd_en = 1'b0;
    // Handle empty condition
end
```

## Flag Timing
- **wr_full**: Updates 1-3 cycles after read operation (due to CDC)
- **rd_empty**: Updates 1-3 cycles after write operation (due to CDC)

## Gray Code Cheat Sheet
```
Binary | Gray
-------|------
 0000  | 0000
 0001  | 0001
 0010  | 0011
 0011  | 0010
 0100  | 0110
 0101  | 0111
 0110  | 0101
 0111  | 0100
 1000  | 1100
 ...
```

Formula: `gray = binary ^ (binary >> 1)`

## Common Issues & Solutions

### Issue: wr_full stuck high
**Solution**: Verify read clock is toggling, check rd_rst_n

### Issue: rd_empty stuck high
**Solution**: Verify write clock is toggling, check wr_rst_n

### Issue: Data mismatch
**Solution**: 
- Check clock ratios aren't extreme (>10:1)
- Verify resets are properly synchronized
- Review timing constraints

### Issue: Compilation errors
**Solution**:
- Use `-g2012` flag with Icarus Verilog
- Check SystemVerilog support in your simulator

## Timing Constraints (SDC)
```tcl
# Define clocks
create_clock -period 10.0 [get_ports wr_clk]
create_clock -period 8.0  [get_ports rd_clk]

# Asynchronous clock groups
set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]

# False paths (optional, for CDC paths)
set_false_path -from [get_cells *wr_ptr_gray_reg*] \
               -to   [get_cells *wr_ptr_gray_sync_stage1_reg*]
set_false_path -from [get_cells *rd_ptr_gray_reg*] \
               -to   [get_cells *rd_ptr_gray_sync_stage1_reg*]

# Max delay for CDC (optional)
set_max_delay 20 -from [get_cells *wr_ptr_gray_reg*] \
                 -to   [get_cells *wr_ptr_gray_sync_stage1_reg*]
set_max_delay 20 -from [get_cells *rd_ptr_gray_reg*] \
                 -to   [get_cells *rd_ptr_gray_sync_stage1_reg*]
```

## Synthesis Attributes

### Xilinx (Vivado)
```systemverilog
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_ptr_gray_sync_stage1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_ptr_gray_sync;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_ptr_gray_sync_stage1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_ptr_gray_sync;
```

### Intel (Quartus)
```systemverilog
(* preserve *) reg [PTR_WIDTH-1:0] wr_ptr_gray_sync_stage1;
(* preserve *) reg [PTR_WIDTH-1:0] wr_ptr_gray_sync;
```

### Synopsys (Design Compiler)
```tcl
set_dont_touch [get_cells *_gray_sync_stage1*]
set_dont_touch [get_cells *_gray_sync_reg*]
```

## Make Commands
```bash
make all      # Compile and run simulation
make compile  # Compile only
make run      # Run simulation only
make wave     # View waveforms in GTKWave
make clean    # Remove generated files
make help     # Show help
```

## File Descriptions

| File                        | Purpose                          |
|-----------------------------|----------------------------------|
| async_fifo.sv               | Main FIFO RTL                    |
| async_fifo_tb.sv            | Testbench with 10 tests          |
| async_fifo_assertions.sv    | SVA properties (optional)        |
| Makefile                    | Build automation                 |
| README.md                   | Complete documentation           |
| ADDITIONAL_TESTS.md         | Extra test case ideas            |
| QUICK_REFERENCE.md          | This file                        |

## Simulation Waveforms to Check

**Essential Signals**:
- wr_clk, rd_clk (verify toggling)
- wr_rst_n, rd_rst_n (verify active low)
- wr_en, wr_data, wr_full
- rd_en, rd_data, rd_empty

**Debug Signals**:
- dut.wr_ptr_bin (write pointer)
- dut.rd_ptr_bin (read pointer)
- dut.wr_ptr_gray (Gray write pointer)
- dut.rd_ptr_gray (Gray read pointer)
- dut.wr_ptr_gray_sync (Synced to read domain)
- dut.rd_ptr_gray_sync (Synced to write domain)

## Performance Metrics

| Metric              | Value            |
|---------------------|------------------|
| Max Write Throughput| 1 word/wr_clk    |
| Max Read Throughput | 1 word/rd_clk    |
| Latency (wr to flag)| 2-3 rd_clk cycles|
| Latency (rd to flag)| 2-3 wr_clk cycles|
| Area (16-deep, 8-bit)| ~150 gates      |

## Recommended Clock Ratios
- **Safe**: 1:1 to 5:1 (either direction)
- **Tested**: Up to 10:1
- **Limit**: Avoid >20:1 ratios

## Memory Implementation

**For Small FIFOs** (<= 1KB):
- Use register array (as in this design)
- Fast, simple, area-efficient

**For Large FIFOs** (> 1KB):
- Consider using SRAM/BRAM
- Modify read path for memory latency
- Add read address pipeline stage

## Checklist for Design Review
- [ ] Parameters set correctly
- [ ] Both clocks defined in constraints
- [ ] Clock groups marked asynchronous
- [ ] Reset strategy documented
- [ ] Simulation passes all tests
- [ ] Synthesis clean (no latches)
- [ ] Timing closed
- [ ] CDC verified
- [ ] Code coverage > 90%
- [ ] Assertions passing

## Contact & Support
For design questions, refer to:
1. Inline comments in source files
2. README.md for detailed documentation
3. ADDITIONAL_TESTS.md for test strategies

---

**Version**: 1.0  
**Last Updated**: 2025-01-09  
**Compatible With**: Icarus Verilog, VCS, Questa, Vivado, Quartus
