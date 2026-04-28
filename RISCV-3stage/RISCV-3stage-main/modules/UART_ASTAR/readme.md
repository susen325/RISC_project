# Custom RISC-V Hardware A* Pathfinding & UART Protocol

This repository demonstrates a bare-metal C implementation of the A* pathfinding algorithm running on a custom 3-stage pipelined RISC-V FPGA soft-core. It features a custom hardware Manhattan Distance accelerator and a robust UART handshaking protocol to transmit the computed path back to a host PC for visualization.

## How the UART Protocol Works

The UART system acts as a bridge between the high-speed FPGA processor (running at 10MHz - 100MHz) and the low-speed serial connection (115200 Baud). It uses Memory-Mapped I/O and strict software handshaking to prevent buffer overruns and ensure data integrity.

### Memory-Mapped I/O (MMIO)
Because the program runs on bare metal without an operating system, the UART transmitter is mapped directly to a specific memory address:

```c
#define UART_TX ((volatile uint32_t*)0x80000040)
```

Writing a 32-bit integer to this address pushes the data into a hardware FIFO trace buffer, which the UART module sequentially shifts out over the physical TX pin.

### The Handshaking Sequence
The CPU executes instructions exponentially faster than the UART can transmit bits. To prevent BRAM wraparound and to filter out electrical noise generated during physical board resets, the system uses the following sequence:

1. **Start Marker (`0xAAAAAAAA`):** Sent after a brief startup delay. The Python receiver silently drops all incoming data (line noise/reset glitches) until it reads this exact 32-bit sequence.
2. **Pacing Delays:** The C code uses `for(volatile int d = 0; d < 50000; d++);` between hardware writes to stall the CPU, giving the hardware UART transmitter time to empty its FIFO buffer.
3. **Data Payload:** The algorithm transmits the total step count, followed by the sequential array of node indices representing the solved path.
4. **Error Handling (`0xDEAD0000`):** Sent if the pathfinding algorithm fails to find a valid route to the goal.
5. **EOF Marker (`0xFFFFFFFF`):** Sent at the end of execution to signal the Python script to close the serial port and render the visualization.

---

## Prerequisites

* An FPGA board programmed with the custom RISC-V SoC bitstream.
* A micro-USB/UART cable connecting the FPGA to the host PC.
* Python 3.x installed on the host PC.
* The `pyserial` library installed:
  ```bash
  pip install pyserial
  ```

---

## Setup and Execution Example

The following steps demonstrate how to compile, flash, and execute the `astar_2.c` maze solver and visualize the output using the Python receiver script.

### Step 1: Compile the C Code
Open your terminal in the project directory and use the Makefile to compile the bare-metal C code into a memory initialization file (`imem.mem`).

```bash
make SRC='astar_2.c'
```

### Step 2: Flash the Instruction Memory
Put your FPGA board into **Programming Mode** (flip the designated bootloader switch to HIGH). Run the sender script to push the compiled instructions into the FPGA's instruction RAM over UART.

```bash
python send_copy.py imem.mem COM7
```
Wait for the terminal to confirm that all bytes have been successfully transmitted.

### Step 3: Start the Receiver
Flip the programming switch on the FPGA back to **LOW (Execution Mode)**. 
**Do not press the reset button yet.** First, start the visualization receiver script so it begins listening on the COM port.

```bash
python receiver_for_astar_2.py
```
The terminal will indicate it is listening on COM7.

### Step 4: Execute on Hardware
Press and hold the physical **Reset button** on your FPGA board for roughly one second to flush the pipeline registers, then release it. 

The Python terminal will catch the handshake, download the path, and render the visualizer:

```text
Listening on COM7...
Press Ctrl+C at any time to forcefully stop listening.

Waiting for FPGA...
Start Marker (0xAAAAAAAA) Received! Recording Path...

Total Steps: 15
EOF Marker Received! Rendering Map...

U-TURN MAZE VISUALIZATION:

. . . . . . . G 
. . # # # # # # 
. . # . . . . . 
. . # . . . . . 
. . # . . . . . 
. . # . . . . . 
. . # . . . . . 
. . . . . . . S 
```

---

## Receiver Script Code (`receiver_for_astar_2.py`)
For reference, here is the complete Python receiver script used to capture and visualize the UART data stream. 

```python
import serial
import sys

COM_PORT = 'COM7'
WALLS = [10, 11, 12, 13, 14, 15, 18, 26, 34, 42, 50]

def draw_maze(path_nodes):
    print("\nU-TURN MAZE VISUALIZATION:\n")
    for r in range(8):
        row_str = ""
        for c in range(8):
            idx = r * 8 + c
            if idx == 63: row_str += "S "    # Start is Bottom Right
            elif idx == 7: row_str += "G "   # Goal is Top Right
            elif idx in path_nodes: row_str += "* "
            elif idx in WALLS: row_str += "# "
            else: row_str += ". "
        print(row_str)

try:
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    ser.reset_input_buffer()
    started = False
    receiving_path = False
    path = []
    
    print(f"Listening on {COM_PORT}...")
    print("Waiting for FPGA...")
    
    while True:
        raw_bytes = ser.read(4)
        if len(raw_bytes) == 0: 
            continue
            
        word = int.from_bytes(raw_bytes, byteorder='big')
        
        if not started:
            if word == 0xAAAAAAAA: 
                print("Start Marker Received! Recording Path...\n")
                started = True
            continue
            
        if word == 0xFFFFFFFF:
            print("EOF Marker Received! Rendering Map...")
            draw_maze(path)
            break
            
        if word == 0xDEAD0000:
            print("PATH NOT FOUND.")
            continue
            
        if not receiving_path:
            print(f"Total Steps: {word}")
            receiving_path = True
        else:
            path.append(word)
            
    ser.close()
    
except KeyboardInterrupt: 
    print("\nManually stopped by user.")
    sys.exit(0)
except serial.SerialException:
    print(f"\nERROR: Could not open {COM_PORT}. Is it open in Vivado or another terminal?")
    sys.exit(1)
```
