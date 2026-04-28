# Processor 2: Custom Out-of-Order RISC-V Processor (Tomasulo's Algorithm)

## Overview
This project implements a custom Out-of-Order (OoO) RISC-V processor utilizing Dynamic Scheduling (Tomasulo's Algorithm). Designed for and tested on the Digilent Nexys A7-100T FPGA, this architecture eliminates false data dependencies and allows independent instructions to bypass stalled multi-cycle operations (such as 32-cycle multiplication and division) in real-time.

## Architectural Highlights
* **Dynamic Scheduling:** Utilizes Reservation Stations to queue instructions and monitor the Common Data Bus (CDB) for operands, allowing true out-of-order execution.
* **Hardware Register Renaming:** Implements a Register Alias Table (RAT) to resolve Write-After-Read (WAR) and Write-After-Write (WAW) hazards dynamically.
* **Precise Exceptions:** A Reorder Buffer (ROB) enforces strict In-Order Commit, ensuring the architectural state is perfectly maintained even when execution occurs out-of-order.
* **Advanced Memory Disambiguation:** Hardware memory barriers actively resolve Read-After-Write (RAW) memory hazards between consecutive Load (`LW`) and Store (`SW`) instructions.
* **Visual Execution Dashboard:** Features a custom hardware wrapper that slows the processor to a 1 Hz "human speed" clock, outputting real-time execution states (e.g., ALU, MUL, DIV activity) to a multiplexed 7-segment display.

## Hardware and Software Requirements
* **Target FPGA:** Digilent Nexys A7-100T (`xc7a100tcsg324-1`)
* **EDA Tool:** Xilinx Vivado (Tested on versions 2022.x / 2023.x)
* **Language:** Verilog-2001

---

## Simulation Guide
Before generating the physical bitstream, the architecture should be verified using Vivado's behavioral simulator.

### 1. Project Initialization
1. Upload all Verilog source files into Vivado. Add testbench files to **Simulation Sources** and all other modules to **Design Sources**.

### 2. Loading the Assembly
1. Write a RISC-V assembly test program explicitly designed to create data hazards and convert it to 32-bit Hex machine code.
2. Save this file as `imem.hex` inside the project directory.
3. **Critical Vivado Step:** Ensure `imem.hex` is explicitly added to the Vivado project. Right-click the file in the **Sources** window, select **Source Node Properties**, and set the Type to **Memory File**.

### 3. Running the Testbench
1. Ensure the appropriate testbench file (e.g., `tb_top_core.v`) is set as the active top module under **Simulation Sources**.
2. Navigate to **Run Simulation** > **Run Behavioral Simulation**.
3. In the waveform viewer, add the following critical signals to observe out-of-order execution:
   * `pc_reg`: To monitor instruction fetching.
   * `cdb_valid` and `cdb_tag`: To monitor the broadcast network.
   * `rs_mul_busy` and `rs_div_busy`: To observe multi-cycle execution stalls.
   * `commit_reg_we` and `commit_reg_data`: To verify precise, in-order commits from the ROB.
4. Run the simulation for a minimum of 2000 ns to ensure all multi-cycle instructions fully resolve.

---

## FPGA Deployment and Execution Guide
This project includes a custom hardware wrapper (`fpga_top.v`) that divides the board's 100MHz clock down to roughly 1 Hz, allowing for human observation of the dynamic scheduling process.

### 1. Project Setup
1. Open Vivado and ensure `fpga_top.v` is set as the Top Module under **Design Sources**.
2. Verify that the `.xdc` constraints file is properly loaded and correctly maps the clock, reset button, LEDs, and 7-segment display pins for the Nexys A7.
3. Open `memory.v` and verify that the `$readmemh` command uses an absolute file path to the `imem.hex` file. This prevents the synthesizer from generating blank Block RAM.

### 2. Bitstream Generation
1. Click **Run Synthesis**.
2. Click **Run Implementation**.
3. Click **Generate Bitstream**.
   > **Note:** Ensure there are no unconstrained pin errors. If the build fails during pin planning, verify that the selected FPGA part number in Vivado matches the physical development board.

### 3. Hardware Execution
1. Connect the Nexys A7-100T via USB and toggle the power switch to ON.
2. In Vivado, navigate to **Open Hardware Manager** > **Auto Connect** > **Program Device**.
3. Once programmed, firmly press and release the `CPU_RESET` button (Pin C12).
4. **Observe the Dashboard:**
   * **Heartbeat LED:** The far-left LED (`LED[15]`) will blink steadily, confirming the 1 Hz divided clock is active.
   * **7-Segment Display:** The display will show the final data output, alongside character codes representing the actively executing hardware units:
     * `A` = ALU
     * `P` = Product (Multiplier)
     * `d` = Divider
     * `L` = Load/Store
     * `S` = Stall
   * **Out-of-Order Verification:** Observe the dashboard characters. The fast ALU (`A`) will trigger and complete multiple times while the slow Multiplier (`P`) remains locked on, physically demonstrating that independent instructions are bypassing the stalled mathematical unit.
