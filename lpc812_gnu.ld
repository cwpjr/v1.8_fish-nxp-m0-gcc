ENTRY(Reset_Handler)

/* NXP LPC boot ROM "valid user code" criterion: the reserved vector slot 7
   (offset 0x1C) must hold the 2's complement of the checksum of vectors 0-6
   so the sum of the first 8 entries is 0, else the part enters UART ISP
   instead of running flash. Computed at link time from the Thumb-bit
   function symbol values, exactly as stored. */
/* ld strips the Thumb bit from function symbols in arithmetic, so each
   handler needs +1 to match the odd values actually stored in the table
   (same +1 idiom as NXP's own managed linker scripts). */
__vector_checksum = 0 - (_estack + (Reset_Handler + 1) + (NMI_Handler + 1)
                       + (HardFault_Handler + 1) + (MemManage_Handler + 1)
                       + (BusFault_Handler + 1) + (UsageFault_Handler + 1));

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS
{
    .isr_vector ORIGIN(FLASH) :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } > FLASH

    .text :
    {
        . = ALIGN(4);
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
    } > FLASH

    .ARM.extab : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > FLASH
    .ARM.exidx : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } > FLASH

    .FISH_Ram_MemMap ORIGIN(RAM) (NOLOAD) :
    {
        . = ALIGN(4);
        KEEP(*(FISH_Ram_MemMap .FISH_Ram_MemMap))
        . = ALIGN(4);
    } > RAM

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH
    _sidata = LOADADDR(.data);

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.* COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    .heap (NOLOAD) :
    {
        . = ALIGN(8);
        _heap_start = .;
        . += 0x40;
        _heap_end = .;
    } > RAM

    .stack _heap_end (NOLOAD) :
    {
        _stack_bottom = .;
        /* Sized to fit below ALL_UNINITRAM_START (0x10000D40): slack was 0xB0.
           0xA0 keeps >=128 bytes for IAP flash calls + 16B guard below DBAUD. */
        . += 0xA0;
        _estack = .;
    } > RAM

    /DISCARD/ : { *(.comment) *(.note*) }
}

ASSERT(SIZEOF(.text) + SIZEOF(.isr_vector) <= LENGTH(FLASH), "LPC812 flash overflow")
ASSERT(_estack <= 0x10000D40, "C data/stack overlaps FISH uninitialized RAM and VM stacks")
ASSERT(ADDR(.FISH_Ram_MemMap) + SIZEOF(.FISH_Ram_MemMap) <= _heap_start, "FISH RAM map overlaps C data/stack")