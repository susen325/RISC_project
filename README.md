A* Pathfinding SoC with Out-of-Order RISC-V Accelerator
Group Number: 4

📌 Overview
This project is a custom RISC-V System-on-Chip (SoC) designed as a dedicated hardware accelerator for grid-based pathfinding. It solves the computational bottleneck of slow software routing through two major architectural innovations:

Custom Hardware Acceleration: A single-cycle Manhattan Distance (MANDIST) instruction to instantly calculate grid heuristics.

Dynamic Scheduling: An Out-of-Order (OoO) execution engine based on Tomasulo's Algorithm, allowing the processor to mask multi-cycle data hazards and execute independent instructions simultaneously.

Designed for the Digilent Nexys A7-100T FPGA, the SoC reads coordinates via Memory-Mapped I/O (MMIO) switches, executes an optimized A* search algorithm, and outputs results—alongside a real-time Execution Dashboard—directly to the board's 7-segment display.

🏗️ Architectural Features
Dynamic Scheduling (Tomasulo's Algorithm): Utilizes Reservation Stations and a Common Data Bus (CDB) to queue instructions, eliminating false data dependencies and allowing true out-of-order execution.

Hardware Register Renaming: Implements a Register Alias Table (RAT) to resolve Write-After-Read (WAR) and Write-After-Write (WAW) hazards on the fly.

Precise Exceptions (ROB): A Reorder Buffer enforces strict In-Order Commit, ensuring architectural safety even when execution occurs out-of-order.

Custom ALUs: * MANDIST: Calculates Manhattan Distance (|x1-x2| + |y1-y2|) in a single clock cycle.

RAND: Hardware-accelerated random integer generation.

Memory Disambiguation: Hardware memory barriers actively resolve Read-After-Write (RAW) memory hazards between consecutive Load and Store instructions.

🎯 Use Cases & Hardware Relevance
Delivery & Robotics Routing: Acts as a high-speed routing brain for automated warehouse robots or grid-based delivery logistics.

Instruction-Level Parallelism: Speeds up A* search programs twofold: first by executing heavy distance math in 1 cycle, and second by allowing loop overhead and memory pointer generation to execute simultaneously in the background via the OoO pipeline.

Deterministic Timing: Unlike software processors, the FPGA hardware guarantees consistent execution time critical for real-time embedded systems.

💻 Simulation Guide
Before generating the bitstream, verify the architecture using Vivado's behavioral simulator.

1. Load the Assembly
Write your A* assembly program and compile it to 32-bit Hex machine code.

Save this as imem.hex inside your project directory.

Critical Vivado Step: Ensure imem.hex is explicitly added to the Vivado project. Right-click the file in the Sources window, select Source Node Properties, and set the Type to Memory File.

2. Run the Testbench
Ensure tb_top_core.v is set as the active top module under Simulation Sources.

Run the Behavioral Simulation and monitor the following signals:

cdb_valid and cdb_tag (To watch the out-of-order broadcast network).

rs_mul_busy / rs_alu_busy (To observe multi-cycle stalls and bypasses).

commit_reg_we (To verify precise, in-order commits from the ROB).

🚀 FPGA Deployment & Execution
This system includes a custom hardware wrapper (fpga_top.v) that divides the board's 100MHz clock down to ~1 Hz, allowing you to physically watch the processor dynamically schedule instructions.

1. Generate Bitstream
Open Vivado and ensure fpga_top.v is set as the Top Module.

Verify the pins.xdc file correctly maps the Clock, Reset Button, 16 Slide Switches, and the 7-Segment Display.

Click Generate Bitstream and wait for completion.

2. Running on the Silicon
Connect the Nexys A7-100T via USB. Open the Hardware Manager and Program the Device.

Provide Input: Use the 16 physical slide switches (SW0 - SW15) to input the start and end grid coordinates.

Start Execution: Press and release the CPU_RESET button (Pin C12).

Observe the Dashboard:

Heartbeat LED: LED[15] will blink steadily, proving the 1 Hz clock is ticking.

Data Output: The right side of the 7-segment display will show the shortest-path distance result.

Execution Status: The left side of the display will output character codes showing exactly which hardware units are actively running (A = ALU, P = Multiplier, d = Divider, L = Load/Store, S = Stall).
