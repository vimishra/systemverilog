# Makefile for Async FIFO Simulation with Icarus Verilog

# Compiler
IVERILOG = iverilog
VVP = vvp

# Source files
RTL_SRC = async_fifo.sv
TB_SRC = async_fifo_tb.sv
ASSERT_SRC = async_fifo_assertions.sv

# Output files
VVP_FILE = async_fifo_tb.vvp
VCD_FILE = async_fifo_tb.vcd

# Compilation flags
IVERILOG_FLAGS = -g2012 -Wall

# Default target
all: compile run

# Compile the design
compile:
	@echo "Compiling Async FIFO design..."
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(VVP_FILE) $(RTL_SRC) $(TB_SRC)
	@echo "Compilation complete!"

# Run simulation
run:
	@echo "Running simulation..."
	$(VVP) $(VVP_FILE)
	@echo "Simulation complete! Check $(VCD_FILE) for waveforms."

# View waveforms (requires Surfer)
wave:
	@echo "Opening waveform viewer..."
	surfer $(VCD_FILE) &

# Clean generated files
clean:
	@echo "Cleaning up..."
	rm -f $(VVP_FILE) $(VCD_FILE)
	@echo "Clean complete!"

# Help
help:
	@echo "Async FIFO Makefile Targets:"
	@echo "  make all     - Compile and run simulation (default)"
	@echo "  make compile - Compile the design only"
	@echo "  make run     - Run the simulation"
	@echo "  make wave    - View waveforms in Surfer"
	@echo "  make clean   - Remove generated files"
	@echo "  make help    - Show this help message"

.PHONY: all compile run wave clean help
