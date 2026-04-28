Custom Out-of-Order RISC-V Processor (Tomasulo's Algorithm)
📌 Overview
This project implements a custom Out-of-Order (OoO) RISC-V processor using Dynamic Scheduling (Tomasulo's Algorithm). Designed for and tested on the Digilent Nexys A7-100T FPGA, this architecture eliminates false data dependencies and allows independent instructions to bypass stalled multi-cycle operations (like 32-cycle Multiplication and Division) in real-time.

Architectural Highlights
Dynamic Scheduling: Utilizes Reservation Stations to queue instructions and monitor the Common Data Bus (CDB) for operands, allowing true out-of-order execution.

Hardware Register Renaming: Implements a Register Alias Table (RAT) to resolve Write-After-Read (WAR) and Write-After-Write (WAW) hazards on the fly.

Precise Exceptions: A Reorder Buffer (ROB) enforces strict In-Order Commit, ensuring architectural state is perfectly maintained even when execution occurs out-of-order.

Advanced Memory Disambiguation: Hardware memory barriers actively resolve Read-After-Write (RAW) memory hazards between consecutive LW and SW instructions.

Visual Execution Dashboard: Features a custom hardware wrapper that slows the processor to a 1 Hz "human speed" clock, outputting real-time execution states (e.g., ALU, MUL, DIV activity) to a multiplexed 7-segment display.

🛠️ Hardware & Software Requirements
Target FPGA: Digilent Nexys A7-100T (xc7a100tcsg324-1)

EDA Tool: Xilinx Vivado (Tested on 2022.x / 2023.x)

Language: Verilog-2001

💻 Simulation Guide
Before generating physical hardware, the architecture should be verified using Vivado's behavioral simulator.
0. UPLOAD ALL VERILOG FILES ON VIVADO (for simulation add in simulation sources,for implementation add in design sources)

1. Load the Assembly
Write your RISC-V assembly test gauntlet and convert it to 32-bit Hex machine code.

Save this as imem.hex inside your project directory.

Critical Vivado Step: Ensure imem.hex is explicitly added to your Vivado project. Right-click the file in the Sources window, select Source Node Properties, and set the Type to Memory File.

2. Run the Testbench
Ensure your testbench file (e.g., tb_top_core.v) is set as the active top module under Simulation Sources.

Click Run Simulation -> Run Behavioral Simulation.

In the waveform viewer, add the following critical signals to observe out-of-order execution:

pc_reg (To watch instruction fetching)

cdb_valid and cdb_tag (To watch the broadcast network)

rs_mul_busy / rs_div_busy (To observe multi-cycle stalls)

commit_reg_we and commit_reg_data (To verify in-order commit)

Run the simulation for at least 2000 ns to allow multi-cycle instructions to finish.

🚀 FPGA Deployment & Execution Guide
This project includes a custom hardware wrapper (fpga_top.v) that divides the board's 100MHz clock down to roughly 1 Hz, allowing you to physically watch the processor dynamically schedule instructions.

1. Project Setup
Open Vivado and ensure fpga_top.v is set as the Top Module under Design Sources.

Verify that your .xdc constraints file is loaded and correctly maps the clock, reset button, LEDs, and 7-segment display pins for the Nexys A7.

Open your memory.v file and ensure the $readmemh command uses an absolute path to your imem.hex file to prevent the synthesizer from generating blank Block RAM.

2. Generate Bitstream
Click Run Synthesis.

Click Run Implementation.

Click Generate Bitstream.
(Note: Ensure there are no unconstrained pin errors. If the build fails on pin planning, verify your selected FPGA part number matches your physical board).

3. Running on the Silicon
Connect the Nexys A7 via USB and turn on the power switch.

In Vivado, click Open Hardware Manager -> Auto Connect -> Program Device.

Once programmed, firmly press and release the CPU_RESET button (Pin C12).

Observe the Board:

Heartbeat LED: The far-left LED (led[15]) will blink steadily, proving the 1 Hz slow clock is ticking.

7-Segment Dashboard: The display will show the final data output, as well as character codes representing active execution units (A for ALU, P for Product/MUL, d for DIV, L for Load/Store, S for Stall).

Out-of-Order Proof: Watch the dashboard carefully. You will see the fast ALU (A) trigger and complete multiple times while the slow Multiplier (P) remains locked on, proving independent instructions are physically bypassing the stalled math unit.

⚠️ Troubleshooting
The board is programmed, but the LEDs are completely dead / The PC counts up forever: Vivado silently failed to load your imem.hex file during synthesis. Ensure the file type is explicitly set to Memory File in the properties pane, and use an absolute file path in your $readmemh command.

The answer flashes instantly and I can't see the execution:
Your clock divider is too small. Check fpga_top.v and ensure you are using a high enough bit from your counter (e.g., clk_div[26]) to step the 100MHz clock down to human speeds.
