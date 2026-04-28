# ==========================================
# Bare-Metal RISC-V Build System
# ==========================================

# Toolchain
CC      = riscv64-linux-gnu-gcc
OBJCOPY = riscv64-linux-gnu-objcopy
PYTHON  = python

# Files
SRC = astar.c
ELF = firmware.elf
BIN = firmware.bin
MEM = imem.mem

# Compiler & Linker Flags (Nukes OS Bloat & PIE)
CFLAGS  = -O1 -march=rv32im -mabi=ilp32 -nostdlib -ffreestanding -fno-PIE -no-pie
LDFLAGS = -Wl,-N -Wl,--build-id=none -Wl,--no-warn-rwx-segments -T linker.ld

# Default target runs when you just type 'make'
all: $(MEM)

# Step 1: Compile C to ELF executable
$(ELF): $(SRC)
        $(CC) $(CFLAGS) $(LDFLAGS) $(SRC) -o $(ELF)

# Step 2: Extract pure machine code binary
$(BIN): $(ELF)
        $(OBJCOPY) -O binary $(ELF) $(BIN)

# Step 3: Convert binary to hex memory file
$(MEM): $(BIN)
        $(PYTHON) bin_to_mem.py

# Bonus Step: Flash to board
flash: $(MEM)
        $(PYTHON) send_code.py

# Clean up old build files
clean:
        rm -f $(ELF) $(BIN) $(MEM)

.PHONY: all clean flashl
