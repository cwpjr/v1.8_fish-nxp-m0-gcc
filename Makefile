CROSS_COMPILE ?= arm-none-eabi-
CC := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
SIZE := $(CROSS_COMPILE)size
NM := $(CROSS_COMPILE)nm

BUILD_DIR ?= build/gcc
CPUFLAGS := -mcpu=cortex-m0plus -mthumb
ASM_DEFINES := -DNXP_M0_812 -DFISH_PubRel_WORDSET -DNXP_M0_81x_IRC12_24MHZ -DNXP_M0_016kFlash_1KWrite -DNXP_M0_004kRam -DFISH_NO_TIMESTAMP -DFISH_LEAN_WORDSET -DFISH_DICT_2K
# Keep in sync with FLASH_SPAGE in FISH_M0_EQUATES.h for the active config!
FLASH_SPAGE_HEX := 0x3800
CFLAGS := $(CPUFLAGS) $(ASM_DEFINES) -std=gnu11 -Os -ffreestanding -ffunction-sections -fdata-sections -fno-common -Wall -Wextra -I.
ASFLAGS := $(CPUFLAGS) $(ASM_DEFINES) -I.
LDFLAGS := $(CPUFLAGS) -nostdlib -Wl,--gc-sections -Wl,-Map,$(BUILD_DIR)/fish.map -Tlpc812_gnu.ld

FORTH_INCLUDES := \
	FISH_NXP_M0_MAIN_INCLUDES.h \
	FISH_AUTHOR.h \
	io_NXP_M0+_header.h \
	FISH_ARM_CORTEX_M_REGS.h \
	FISH_NXP_M0_MACROS.h \
	FISH_RM_CONFIG_\#DEFINES.h \
	FISH_M0_EQUATES.h \
	FISH_NXP_M0_SLIB.s \
	FISH_NXP_M0_COLD.s \
	FISH_NXP_M0_MEMMAP.s \
	FISH_CO_MSGS.h \
	FISH_NXP_M0_812_UART0_INIT.s \
	FISH_NXP_M0_FLASH.s \
	FISH_RM_MSGS.h \
	FISH_NXP_M0_812_SOC_INIT.s
OBJECTS := $(BUILD_DIR)/FISH_NXP_M0_Forth_GNU.o $(BUILD_DIR)/startup_lpc812_gnu.o $(BUILD_DIR)/main.o

.PHONY: all clean size fitcheck
all: $(BUILD_DIR)/fish.hex $(BUILD_DIR)/fish.sym $(BUILD_DIR)/fish.map fitcheck

# Fail the build if the kernel image overlaps the dictionary flash pages.
# The flash save code writes whole sectors and is blind to the kernel extent.
fitcheck: $(BUILD_DIR)/fish.hex
	python3 ../tools/fish_check_fit.py $< --spage $(FLASH_SPAGE_HEX)

$(BUILD_DIR)/FISH_NXP_M0_Forth_GNU.o: FISH_NXP_M0_Forth_GNU.S $(FORTH_INCLUDES)
	mkdir -p $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/startup_lpc812_gnu.o: startup_lpc812_gnu.S
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPUFLAGS) -c $< -o $@

$(BUILD_DIR)/main.o: main.c LPC11xx.h core_cm0.h core_cmInstr.h core_cmFunc.h system_LPC11xx.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/fish.elf $(BUILD_DIR)/fish.map &: $(OBJECTS) lpc812_gnu.ld
	$(CC) $(LDFLAGS) $(OBJECTS) -lgcc -o $(BUILD_DIR)/fish.elf

$(BUILD_DIR)/fish.hex: $(BUILD_DIR)/fish.elf
	$(OBJCOPY) -O ihex $< $@

$(BUILD_DIR)/fish.sym: $(BUILD_DIR)/fish.elf
	$(NM) -n -S $< > $@

size: $(BUILD_DIR)/fish.elf
	$(SIZE) $<

clean:
	rm -rf $(BUILD_DIR)