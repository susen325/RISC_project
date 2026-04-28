# Processor 1: A* Pathfinding SoC with Custom Hardware Accelerator

## Overview
This architecture is a customized 3-stage pipelined RISC-V System-on-Chip (SoC) designed specifically to accelerate the A* (A-Star) pathfinding algorithm. By identifying the heuristic calculation as a major software bottleneck, this processor utilizes hardware-software co-design to offload Manhattan Distance math directly into silicon. 

## Architectural Features
* **Custom MANDIST Accelerator:** Implements a custom RISC-V instruction (Opcode `0x0B`) that calculates the Manhattan Distance (`|x1-x2| + |y1-y2|`) in a single clock cycle, vastly accelerating grid-based node evaluation.
* **RV32IM Support:** Full support for base integer instructions alongside the M-Extension, featuring a multi-cycle multiplier and divider for complex address generation and arithmetic.
* **UART Communication Bridge:** Features a highly optimized, low-LUT serial communication bridge.
  * **Inbound (RX):** Allows compiled C code (`imem.hex`) to be flashed directly to the processor's Instruction Memory via a Python script without requiring FPGA resynthesis.
  * **Outbound (TX):** Utilizes an asynchronous Trace Buffer (a BRAM-backed FIFO) to catch high-speed 32-bit coordinates from the CPU and transmit them back to the host laptop at 115200 Baud, preventing pipeline stalls during I/O.
* **Memory-Mapped I/O (MMIO):** The trace buffer and custom peripherals are accessed safely by the C code via dedicated memory addresses (e.g., `0x80000040`).

## Simulation Guide
1. Ensure your A* C program has hardcoded grid obstacles and is compiled to a 32-bit Hex machine code format.
2. Ensure `imem.hex` and `dmem.hex` are explicitly added to the Vivado project and defined as Memory Files in the Source Node Properties.
3. Set your pipeline testbench as the active top module under Simulation Sources.
4. Run the Behavioral Simulation to verify the `MANDIST` ALU triggers correctly upon receiving the `CUSTOM0` opcode.

## FPGA Deployment
1. Open Vivado and set `top_fpga.v` as the Top Module.
2. Verify the `nexys_a7.xdc` constraints file correctly maps the System Clock, Reset, and UART RX/TX pins.
3. Generate the Bitstream and program the Nexys A7-100T.
4. Run the provided Python scripts in `UART_ASTAR/UART_SEND_IMEM` to transmit your compiled `imem.hex` to the board over the COM port.
5. Open a terminal emulator (e.g., PuTTY or TeraTerm) connected to the board's COM port at 115200 Baud to view the outputted shortest-path coordinates.
