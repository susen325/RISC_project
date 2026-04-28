import serial
import sys

# Ensure this matches your actual COM port!
COM_PORT = 'COM7'
BAUD_RATE = 115200

try:
    print(f"🎧 Listening on {COM_PORT}...")
    print("💡 Press Ctrl+C at any time to forcefully stop listening.\n")

    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    ser.reset_input_buffer()

    print("⏳ Waiting for FPGA to compute and send data...\n")

    count = 1
    started = False  # <--- FIXED: The missing handshake flag!

    while True:
        raw_bytes = ser.read(4)

        if len(raw_bytes) == 0:
            continue

        word = int.from_bytes(raw_bytes, byteorder='big')

        # Ignore garbage until we see the start marker!
        if not started:
            if word == 0xAAAAAAAA:
                print("🚀 Start Marker (0xAAAAAAAA) Received! Recording Path...\n")
                started = True
            continue

        if word == 0xFFFFFFFF:
            print("\n✅ EOF Marker Received! Test Complete.")
            break

        print(f"Data {count}: Hex = 0x{word:08X} | Decimal = {word}")
        count += 1

    ser.close()

except serial.SerialException:
    print(f"\n❌ ERROR: Could not open {COM_PORT}. Is it open in Vivado or another terminal?")
except KeyboardInterrupt:
    print("\n\n🛑 Manually stopped by user (Ctrl+C).")
    if 'ser' in locals() and ser.is_open:
        ser.close()
        print("🔌 Serial port closed safely.")
    sys.exit(0)
