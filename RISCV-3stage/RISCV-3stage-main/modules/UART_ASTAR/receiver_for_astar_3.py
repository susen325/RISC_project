import serial, sys
COM_PORT = 'COM7' #replace with your port
WALLS = [8,9,10,11,12,13,14, 25,26,27,28,29,30,31, 40,41,42,43,44,45,46]

def draw_maze(path_nodes):
    print("\n⚡ ZIG-ZAG MAZE VISUALIZATION:\n")
    for r in range(8):
        row_str = ""
        for c in range(8):
            idx = r * 8 + c
            if idx == 0: row_str += "🟢"
            elif idx == 56: row_str += "🎯"
            elif idx in path_nodes: row_str += "🟦"
            elif idx in WALLS: row_str += "🧱"
            else: row_str += "⬜"
        print(row_str)

try:
    ser = serial.Serial(COM_PORT, 115200, timeout=1)
    ser.reset_input_buffer()
    started = False; receiving_path = False; path = []
    print("⏳ Waiting for FPGA to solve Zig-Zag...")
    while True:
        raw_bytes = ser.read(4)
        if len(raw_bytes) == 0: continue
        word = int.from_bytes(raw_bytes, byteorder='big')
        if not started:
            if word == 0xAAAAAAAA: started = True
            continue
        if word == 0xFFFFFFFF: draw_maze(path); break
        if word == 0xDEAD0000: print("❌ PATH NOT FOUND."); continue
        if not receiving_path: print(f"📏 Total Steps: {word}"); receiving_path = True
        else: path.append(word)
    ser.close()
except KeyboardInterrupt: sys.exit(0)
