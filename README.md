# Advanced RISC-V Architectures: Custom A* Accelerator and Dynamic Out-of-Order Execution Engine

**Authors:** Group 4 | Computer Science and Engineering, IIT Guwahati  
**Target Hardware:** Digilent Nexys A7-100T FPGA

## Overview
This repository contains the RTL implementation of two distinct, highly customized 32-bit RISC-V processor architectures. Rather than building a single monolithic core, this project explores two different approaches to solving computational bottlenecks: Application-Specific Hardware Acceleration and Instruction-Level Parallelism. 

The repository is divided into two main processor designs:

### 1. Processor 1: A* Pathfinding SoC (`/modules`)
A static, 3-stage pipelined RISC-V System-on-Chip (SoC) designed as a dedicated hardware accelerator for grid-based routing. It features the standard RV32I base integer instruction set, the M-Extension for hardware multiplication/division, and a custom `MANDIST` ALU for single-cycle heuristic calculations. This core utilizes a custom UART bridge for loading programs and transmitting routing data back to a host machine.

### 2. Processor 2: Dynamic Execution Engine (`/Dynamic Execution Engin`)
An advanced Out-of-Order (OoO) RISC-V processor implementing Tomasulo's Algorithm. This architecture acts as a testbed for dynamic scheduling, featuring Reservation Stations, a Common Data Bus (CDB), Register Renaming (RAT), and a Reorder Buffer (ROB) for precise exceptions. It successfully demonstrates multi-cycle math instructions being bypassed by independent arithmetic instructions on physical silicon.

## Repository Structure
* `/modules` - Contains all Verilog source files, memory hex files, and testbenches for Processor 1 (The A* Accelerator).
* `/modules/UART_ASTAR/UART_SEND_IMEM` - Contains Python scripts and C code used to compile and transmit instructions to Processor 1 via UART.
* `/Dynamic Execution Engin/with_buffer` - Contains the Verilog source files, testbenches, and memory files for Processor 2 (Tomasulo's Algorithm).

Please refer to the specific `README.md` inside each subfolder for detailed architectural features, simulation guides, and physical deployment instructions.
