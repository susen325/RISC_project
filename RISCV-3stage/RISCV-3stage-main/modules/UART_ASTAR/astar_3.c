#include <stdint.h>

#define UART_TX ((volatile uint32_t*)0x80000040)
#define COLS 8
#define ROWS 8
#define MAX_NODES 64

typedef struct { uint32_t g, f; int parent; int state; } Node;


static inline uint32_t hw_mandist(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (".insn r 0x0B, 0, 0, %0, %1, %2" : "=r" (res) : "r" (a), "r" (b));
    return res;
}
static inline uint32_t pack_coords(uint32_t r, uint32_t c) {
    return (r << 16) | (c & 0xFFFF);
}

static inline void check_neighbor(int nr, int nc, int curr_idx, uint32_t curr_g, int goal_r, int goal_c, volatile Node* nodes, volatile uint32_t* grid) {
    if(nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS) {
        int n_idx = (nr << 3) | (nc & 7);
        if(grid[n_idx] == 0) {
            if (nodes[n_idx].state != 2) {
                uint32_t tentative_g = curr_g + 1;
                if(nodes[n_idx].state == 0 || tentative_g < nodes[n_idx].g) {
                    nodes[n_idx].parent = curr_idx;
                    nodes[n_idx].g = tentative_g;
                    
                    nodes[n_idx].f = tentative_g + hw_mandist(pack_coords(goal_r, goal_c), pack_coords(nr, nc));
                    nodes[n_idx].state = 1;
                }
            }
        }
    }
}

void __attribute__((naked, section(".init"))) _start() {
    asm volatile ("li sp, 0x00000F00"); asm volatile ("j main");
}

int main() {
    volatile Node nodes[MAX_NODES];
    volatile uint32_t grid[MAX_NODES];

    int start_r = 0, start_c = 0;
    int goal_r = 7, goal_c = 7;

    for(int i = 0; i < MAX_NODES; i++) {
        nodes[i].state = 0; nodes[i].g = 0xFFFFFFFF; nodes[i].f = 0xFFFFFFFF; nodes[i].parent = -1; grid[i] = 0;
    }

    // THE WATERFALL WALLS (Forces a jagged Down/Right path)
    grid[2]=1; grid[10]=1; grid[18]=1; grid[26]=1;
    grid[35]=1; grid[43]=1; grid[51]=1; grid[59]=1;

    int start_idx = 0; int goal_idx = 63;
    nodes[start_idx].g = 0;
    nodes[start_idx].f = hw_mandist(pack_coords(goal_r, goal_c), pack_coords(start_r, start_c));
    nodes[start_idx].state = 1;

    int path_found = 0;

    while (1) {
        uint32_t min_f = 0xFFFFFFFF; int curr_idx = -1;
        for(int i = 0; i < MAX_NODES; i++) {
            if(nodes[i].state == 1 && nodes[i].f < min_f) { min_f = nodes[i].f; curr_idx = i; }
        }
        if (curr_idx == -1) break;
        if (curr_idx == goal_idx) { path_found = 1; break; }

        nodes[curr_idx].state = 2;
        int curr_r = curr_idx >> 3; int curr_c = curr_idx & 7;
        uint32_t curr_g = nodes[curr_idx].g;

        check_neighbor(curr_r - 1, curr_c, curr_idx, curr_g, goal_r, goal_c, nodes, grid);
        check_neighbor(curr_r + 1, curr_c, curr_idx, curr_g, goal_r, goal_c, nodes, grid);
        check_neighbor(curr_r, curr_c - 1, curr_idx, curr_g, goal_r, goal_c, nodes, grid);
        check_neighbor(curr_r, curr_c + 1, curr_idx, curr_g, goal_r, goal_c, nodes, grid);
    }

    if (path_found) {
        int current = goal_idx; int previous = -1; int step = 0;
        while (current != -1 && step < 64) {
            int next_node = nodes[current].parent;
            nodes[current].parent = previous;
            previous = current; current = next_node; step++;
            if (previous == start_idx) break;
        }
        for(volatile int d = 0; d < 500000; d++); UART_TX[0] = 0xAAAAAAAA;
        for(volatile int d = 0; d < 50000; d++); UART_TX[0] = step;
        for(volatile int d = 0; d < 50000; d++);
        int forward_trace = previous;
        while (forward_trace != -1) {
            UART_TX[0] = forward_trace;
            for(volatile int d = 0; d < 50000; d++);
            forward_trace = nodes[forward_trace].parent;
        }
    } else {
        for(volatile int d=0; d<500000; d++); UART_TX[0] = 0xAAAAAAAA;
        for(volatile int d=0; d<50000; d++); UART_TX[0] = 0xDEAD0000;
    }
    UART_TX[0] = 0xFFFFFFFF;
    while(1); return 0;
}
