#include <stdint.h>


// The MMIO Address for your Hardware Trace Buffer
#define UART_TX ((volatile uint32_t*)0x80000040)
//#define SWITCH_0   (*((volatile uint32_t*)0x80000000))
//#define SWITCH_1   (*((volatile uint32_t*)0x80000004))
#define LEDS       (*((volatile uint32_t*)0x80000008))
#define SEV_SEG    (*((volatile uint32_t*)0x80000020))

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

int main(){
    uint32_t a = SWITCH_0;
    uint32_t b = SWITCH_1;
// write the values you want to get from mandist insturction from the processor or give coustum input from the swtichs on fpga board
volatile uint32_t nr = a & ((1<<8)-1);
volatile uint32_t nc = a & ((1<<16)-(1<<8));
volatile uint32_t goal_r =b & ((1<<8)-1);
volatile uint32_t goal_c = b & ((1<<16)-(1<<8));
volatile uint32_t result = hw_mandist(pack_coords(nr, nc), pack_coords(goal_r, goal_c));

UART_TX[0] = result;


    // 3. Send the EOF marker to trigger Python to stop
    UART_TX[0] = 0xFFFFFFFF;

    while(1);
    return 0;

}
