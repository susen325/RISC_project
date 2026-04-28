OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

PHDRS
{
    text PT_LOAD;
}

SECTIONS
{
    .text : {
        *(.init)
        *(.text*)
    } > IMEM :text

    .rodata : {
        *(.rodata*)
    } > IMEM :text

    .data : {
        *(.data*)
    } > IMEM :text

    .bss : {
        *(.bss*)
    } > IMEM :text

    /* THE TRASH CAN: Instantly delete all Linux dynamic linking garbage */
    /DISCARD/ : {
        *(.interp)
        *(.note*)
        *(.comment)
        *(.dynamic)
        *(.dynsym)
        *(.dynstr)
        *(.hash)
        *(.gnu.hash)
        *(.eh_frame)
    }
}
