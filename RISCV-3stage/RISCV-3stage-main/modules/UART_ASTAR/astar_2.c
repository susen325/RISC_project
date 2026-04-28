#include <stdint.h>

// The MMIO Address for your Hardware Trace Buffer
#define UART_TX ((volatile uint32_t*)0x80000040)

#define COLS 4
#define ROWS 4
#define MAX_NODES 16

typedef struct {
    uint32_t g, f;
    int parent;
    int state;
} Node;

static inline uint32_t hw_mandist(uint32_t a, uint32_t b) {
    uint32_t res;
    asm volatile (
        ".insn r 0x0B, 0, 0, %0, %1, %2"
        : "=r" (res)
        : "r" (a), "r" (b)
    );
    return res;
}

static inline uint32_t pack_coords(uint32_t r, uint32_t c) {
    return (r << 16) | (c & 0xFFFF);
}

void __attribute__((naked, section(".init"))) _start() {
    asm volatile ("li sp, 0x00000F00");
    asm volatile ("j main");
}

int main() {
    volatile Node nodes[MAX_NODES];
    volatile uint32_t grid[MAX_NODES];

    int start_r = 0, start_c = 0;
    int goal_r = 3, goal_c = 3;

    // Initialization
    for(int i = 0; i < MAX_NODES; i++) {
        nodes[i].state = 0;
        nodes[i].g = 0xFFFFFFFF;
        nodes[i].f = 0xFFFFFFFF;
        nodes[i].parent = -1;
        grid[i] = 0;
    }

    // The Walls
    grid[1 * COLS + 1] = 1;
    grid[1 * COLS + 2] = 1;
    grid[3 * COLS + 2] = 1;

    int start_idx = start_r * COLS + start_c;
    int goal_idx = goal_r * COLS + goal_c;

    nodes[start_idx].g = 0;
    nodes[start_idx].f = hw_mandist(pack_coords(start_r, start_c), pack_coords(goal_r, goal_c));
    nodes[start_idx].state = 1;

    int dr[4];
    dr[0] = -1; dr[1] = 1; dr[2] = 0; dr[3] = 0;

    int dc[4];
    dc[0] = 0; dc[1] = 0; dc[2] = -1; dc[3] = 1;

    int path_found = 0;

    // Core A* Search
    while (1) {
        uint32_t min_f = 0xFFFFFFFF;
        int curr_idx = -1;

        for(int i = 0; i < MAX_NODES; i++) {
            if(nodes[i].state == 1 && nodes[i].f < min_f) {
                min_f = nodes[i].f;
                curr_idx = i;
            }
        }

        if (curr_idx == -1) break;
        if (curr_idx == goal_idx) {
            path_found = 1;
            break;
        }

        nodes[curr_idx].state = 2;
        int curr_r = curr_idx / COLS;
        int curr_c = curr_idx % COLS;

        for(int i = 0; i < 4; i++) {
            int nr = curr_r + dr[i];
            int nc = curr_c + dc[i];

            if(nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS) {
                int n_idx = nr * COLS + nc;
                if(grid[n_idx] == 0) {
                    if (nodes[n_idx].state == 2) continue;

                    uint32_t tentative_g = nodes[curr_idx].g + 1;

                    if(nodes[n_idx].state == 0 || tentative_g < nodes[n_idx].g) {
                        nodes[n_idx].parent = curr_idx;
                        nodes[n_idx].g = tentative_g;
                        nodes[n_idx].f = tentative_g + hw_mandist(pack_coords(nr, nc), pack_coords(goal_r, goal_c));
                        nodes[n_idx].state = 1;
                    }
                }
            }
        }
    }

    // UART Output
    if (path_found) {
        int trace_idx = goal_idx;
        int step = 0;
        int path[16]; // Temporary array to reverse the path

        // Walk backwards from goal to start
        while (trace_idx != -1 && step < 16) {
            path[step] = trace_idx;
            trace_idx = nodes[trace_idx].parent;
            step++;
        }

        // 1. Send the total number of steps
        UART_TX[0] = step;

        // 2. Send the sequence in order (Start -> Goal)
        for(int i = step - 1; i >= 0; i--) {
            UART_TX[0] = path[i];
        }

    } else {
        UART_TX[0] = 0xDEAD0000;
    }

    // 3. Send the EOF marker to trigger Python to stop
    UART_TX[0] = 0xFFFFFFFF;

    while(1);
    return 0;
}
