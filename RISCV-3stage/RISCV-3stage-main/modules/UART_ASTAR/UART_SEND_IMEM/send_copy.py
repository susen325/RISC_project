import serial
import time
import sys

# --- CONFIGURATION ---
# Change this to match your Device Manager COM port (e.g., 'COM3', 'COM4', or '/dev/ttyUSB1' for Linux)
COM_PORT = 'COM7'
BAUD_RATE = 115200
FILE_NAME = 'imem.mem'
# ---------------------

try:
    print(f"Opening {COM_PORT} at {BAUD_RATE} baud...")
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=2)
    time.sleep(2) # Give the port a second to stabilize

    print(f"Reading {FILE_NAME}...")
    with open(FILE_NAME, 'r') as file:
        lines = file.readlines()

    bytes_sent = 0
    instructions = 0

    print("Sending data to FPGA...")
    for line in lines:
        line = line.strip()
        # Skip empty lines
        if not line:
            continue

        # Convert the 8-character hex string (e.g., "00c586b3") into 4 raw bytes
        raw_bytes = bytes.fromhex(line)

        # Reverse the bytes because our Verilog bootloader shifts right!
        # "00c586b3" -> sends B3, then 86, then C5, then 00.
        reversed_bytes = raw_bytes[::-1]

        # Send the 4 bytes over the USB cable
        ser.write(reversed_bytes)

        bytes_sent += 4
        instructions += 1

        # Optional: Add a microscopic delay to ensure the FPGA catches every byte
        time.sleep(0.001)

    print(f"\n✅ SUCCESS! Sent {instructions} instructions ({bytes_sent} bytes).")
    ser.close()

except FileNotFoundError:
    print(f"❌ ERROR: Could not find '{FILE_NAME}'. Is it in the same folder?")
except serial.SerialException:
    print(f"❌ ERROR: Could not open {COM_PORT}. Is the board plugged in and turned on?")
except Exception as e:
    print(f"❌ ERROR: {e}")
