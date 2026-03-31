addi x1, x0, 10  (Load 10)

addi x2, x0, 3   (Load 3)

mul x15, x1, x2  (x15 becomes 30)

div x15, x1, x2  (x15 becomes 3)

rem x15, x1, x2  (x15 becomes 1)

    // tested the result for these instructions and got the the correct output
    you can check the result from simulation-result.txt file 
hexcoded instruction of these instruction are in imem/dmem folder
00A00093
00300113
022081B3
00302023
0220C233
00402023
0220E7B3
00F02023
0000006F change imem.hex for fpga led
