import sys

def convert():
    # Read the raw binary file output by the GCC compiler
    with open('firmware.bin', 'rb') as f:
        binary_data = f.read()

    # Open the final imem.mem file to write to
    with open('imem.mem', 'w') as f:
        # Process the binary data in 4-byte (32-bit) chunks
        for i in range(0, len(binary_data), 4):
            chunk = binary_data[i:i+4]
            # Pad with zeroes if the last chunk is smaller than 4 bytes
            chunk = chunk.ljust(4, b'\x00')

            # Convert to a 32-bit integer (Little-Endian is standard for RISC-V)
            word = int.from_bytes(chunk, byteorder='little')

            # Write as an 8-character hex string
            f.write(f"{word:08x}\n")

    print("✅ Successfully generated imem.mem!")

if __name__ == "__main__":
    convert()
