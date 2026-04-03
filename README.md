Project Abstract (2-3 pages) 
Title : A* Pathfinding SoC with Custom RISC-V Accelerator 
Group Number: 4 
1. System Description 
This project is a RISC-V System-on-Chip (SoC) designed as a dedicated hardware accelerator 
for grid-based pathfinding. It solves the computational bottleneck of slow software routing by 
introducing a custom, single-cycle Manhattan Distance (MANDIST) instruction to instantly 
calculate grid heuristics. The system features a 3-stage pipeline supporting the RV32I base set 
and RV32M (Multiply/Divide) extension. It reads coordinates via FPGA switches (MMIO), 
executes an optimized A* search algorithm, and outputs results directly to the board's 7
segment display 
2. Use Cases -   -   -   
Delivery App Routing: The chip quickly finds the optimized path for a driver moving 
through a city grid from a shop to a house. (Note: This is a grid-based abstraction of 
real-world logistics (e.g., Swiggy/Zomato) designed to demonstrate hardware 
acceleration of Manhattan distance heuristics.) 
Warehouse Robots: The chip acts as a brain for automated robots, helping them find 
the shortest path to pick up items in a large warehouse without hitting walls. 
Faster Search Math: It speeds up A search programs* by doing the heavy distance 
calculations in 1 clock cycle instead of 10, saving thousands of cycles. 
3. FPGA Relevance - - 
Custom Hardware Control: FPGAs allow us to physically reconfigure logic gates to 
create a specialized MANDIST hardware circuit that does not exist on standard laptop 
processors. 
True Parallelism: Unlike software that runs instructions one by one, the FPGA can 
calculate absolute differences for and coordinates simultaneously in a single clock cycle. 
- 
Deterministic Timing: Using an FPGA ensures the routing algorithm has a consistent 
execution time, which is critical for real-time robotics and embedded delivery systems. 
4. System Scope 
Minimum System (Commitment) 
1. Core CPU & RAND: A 3-stage RISC-V pipeline featuring the M-extension and a custom 
RAND hardware instruction for rapid random integer generation. 
2. Basic I/O: Functional Memory-Mapped I/O (MMIO) connecting the processor to physical 
FPGA slide switches and 7-segment displays 
Goal System 
1. MANDIST Accelerator: Integration of the custom MANDIST instruction into the Execute 
stage for single-cycle grid distance calculations. 
2. A Hardware Demo: Running a bare-metal A* assembly program standalone on the 
FPGA to physically prove hardware speedup over software 
Stretch Goal 
1. Branch Prediction: Adding a 2-bit dynamic branch predictor (BHT) to predict 
algorithmic loops and eliminate wasted clock cycles from pipeline flushes. 
2. UART Interface: Building a UART bootloader to quickly send new test coordinates or 
programs from a laptop to the FPGA without regenerating the bitstream. 
3. MAC Accelerator: Adding a single-cycle Multiply-Accumulate (MAC) custom instruction 
to instantly execute (A * B) + C math operations. 
5. Design Goals - - - - 
Latency: The custom A* Manhattan distance instruction will execute entirely within 
combinational logic in the EX stage, achieving a strict 1-cycle latency. 
Throughput: The system will sustain a peak instruction throughput of ~1.0 IPC 
(Instructions Per Clock) during the A* node evaluation phase. 
Resource Usage: Budgeted strictly for the Nexys A7: < 4,000 LUTs total, 0 DSP slices 
(Manhattan distance utilizes standard LUT adders instead of multipliers), and ~16 KB of 
BRAM for dual-port memory. 
Correctness & Speedup: Correctness will be verified via HW/SW co-simulation. The A* 
algorithm will be executed in pure C (baseline) and compared against the hardware
accelerated C code to verify identical path outputs and to measure the exact cycle-count 
speedup 
6. Implementation Approach - - - - - 
Modules: Develop a custom A* accelerator, an MMIO bus controller, a hardware switch 
debouncer, and a 7-segment display driver. 
Datapath Changes: Modify ID/EX control logic to decode the custom opcode, and 
intercept the memory interface to route specific addresses to the MMIO bus. 
Module Verification: Write isolated Verilog testbenches to verify debouncer timing and 
the custom accelerator's math/latency. 
Processor Simulation: Simulate the full CPU pipeline executing fixed RISC-V assembly 
to guarantee the custom instruction doesn't cause pipeline hazards. 
C Program Testing: Write the A* algorithm in C, verify the logic via software, and 
compile to RISC-V to test live on the FPGA using physical MMIO switches. 
7. Demonstration Plan - - - 
Input: The user manually inputs the start and end grid coordinates using the physical 
slide switches on the FPGA board. 
Processing: The custom RISC-V pipeline executes a bare-metal A* assembly program, 
using the hardware MANDIST block to calculate node distances in a single clock cycle. 
Output: The processor routes the final shortest path distance through the MMIO bus to 
instantly light up on the board's 7-segment display. 
8. High Level Timeline  
Requirements 
● Must include at least 5–6 concrete milestones 
● Milestones cannot be generic like “Continue implementation”, “Work on project” 
● Each milestone must produce (deliverable): 
○ (code + testbench) OR FPGA demo (graded) 
● At least one core functionality/module of the minimum system should be 
implemented and tested by Apr 12. 
● Ensure minimum system (commitment) is met by Apr 19. This will leave some room to 
handle last-minute surprises. 
Week 
23 - 29 Mar 
Milestone 
Project scoping, system architecture design, and hardware-software partitioning. 
Deliverable: Finalized Project Abstract and SoC component specification. 
Implement the baseline 3-stage RISC-V pipeline (RV32I + M-extension) and finalize the 
hardware block diagram. 
30 Mar - 5 Apr 
Deliverable: Block Diagram Report + Core Pipeline Verilog code with isolated 
testbenches. 
Develop the MMIO bus controller, switch debouncers, and 7-segment display drivers. 
Integrate the RAND instruction. 
6 Apr - 12 Apr 
Deliverable: Status Report + FPGA Hardware Demo (Processor reading inputs and 
driving display). 
Integrate the MANDIST custom ALU. Write the bare-metal A* routing algorithm and run it 
natively on the board. 
13 Apr - 19 Apr 
Deliverable: Minimum System FPGA Demo (Fully functional hardware-accelerated 
routing). 
Try to Implement Stretch Goals or keep as buffer week: Add the 2-bit dynamic Branch 
Predictor and MAC instruction. Conduct cycle-count performance analysis. 
20 - 26 Apr 
Deliverable: Final High-Performance SoC FPGA Demo + Final Project Report. 
9. Team Work Plan 
● Collaboration Approach: The team will use GitHub for version control to ensure Verilog 
modules can be developed in parallel without overwriting each other's work. We will 
follow a "modular verification" strategy: every individual must prove their assigned 
module works in a simulation testbench before it is integrated into the main pipeline. 
Member 
Responsibilities 
Anay Gupta 
Core 3-stage pipeline datapath control and developing the 
MANDIST hardware accelerator module. 
Ajay Meena 
2-bit dynamic Branch Predictor (stretch goal), UART bootloader 
integration, and full-processor hazard testing. 
Aditya Garg 
Hardware switch debouncer modules and writing isolated Verilog 
testbenches for basic logic verification. 
Divyamsh 
MMIO Address Decoder, 7-segment display hardware drivers, 
and co-designing the system Block Diagram. 
Susen Kumar 
RV32M (Multiply/Divide) extension, writing the bare-metal A* 
assembly/C algorithm, and co-designing the system Block 
Diagram 
10. Github Link - https://github.com/susen325/RISC_project ----------------------------------------------------------------------------------------------------------------------- 
Project Plan is Not accepted if: 
● Timeline missing or milestones are generic 
● No clear demo plan 
