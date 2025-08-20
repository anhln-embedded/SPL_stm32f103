# Simple cross-platform Makefile for STM32F103 projects
# Builds C files in Src/, includes CMSIS/SPL if present, and collects outputs in build/

PROJECT := blinkled
BUILD_DIR := build

# Toolchain
CC := arm-none-eabi-gcc
OBJCOPY := arm-none-eabi-objcopy
OBJDUMP := arm-none-eabi-objdump

# CPU and flags
MCU_FLAGS := -mcpu=cortex-m3 -mthumb
OPT := -O0
CFLAGS := $(MCU_FLAGS) $(OPT) -g -Wall -ffreestanding -fdata-sections -ffunction-sections -fno-common
LDFLAGS := $(MCU_FLAGS) -Wl,--gc-sections -nostartfiles

# Layout
SRC_DIR ?= Src
STARTUP := startup_stm32f103.s
LD_SCRIPT := stm32f103.ld

# Vendor/library default locations (can override when invoking make)
CMSIS_DIR ?= Libraries/CMSIS
STM32_SPL_VENDOR_DIR ?= Libraries/STM32F10x_StdPeriph_Driver
SPL_DIR ?= Libraries/SPL

# Collect sources
CORE_SRCS := $(wildcard $(SRC_DIR)/*.c)
SPL_SRCS := $(wildcard $(SPL_DIR)/*.c) $(wildcard $(SPL_DIR)/src/*.c) $(wildcard $(STM32_SPL_VENDOR_DIR)/src/*.c)
CMSIS_SRCS := $(wildcard $(CMSIS_DIR)/*.c) $(wildcard $(CMSIS_DIR)/Source/*.c)
SRCS := $(CORE_SRCS) $(SPL_SRCS) $(CMSIS_SRCS)

ifeq ($(strip $(SRCS)),)
$(error No C sources found under '$(SRC_DIR)'. Put your sources in '$(SRC_DIR)' or set SRC_DIR.)
endif

# Object list; startup assembled from .s
OBJS := $(SRCS:.c=.o) $(STARTUP:.s=.o)

# Include paths
INCLUDES := -I$(SRC_DIR)
ifeq ($(wildcard Inc),)
$(info Note: no Inc directory found)
else
INCLUDES += -IInc
endif
ifeq ($(wildcard $(STM32_SPL_VENDOR_DIR)/inc),)
$(info Note: no STM32 SPL vendor dir found at '$(STM32_SPL_VENDOR_DIR)/inc'.)
else
INCLUDES += -I$(STM32_SPL_VENDOR_DIR)/inc
endif
ifeq ($(wildcard $(SPL_DIR)),)
$(info Note: no generic SPL directory found at '$(SPL_DIR)'.)
else
INCLUDES += -I$(SPL_DIR)/Include -I$(SPL_DIR)
endif
ifeq ($(wildcard $(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x),)
# allow the user to provide CMSIS device include directly
else
INCLUDES += -I$(CMSIS_DIR)/CM3/DeviceSupport/ST/STM32F10x
endif
ifeq ($(wildcard $(CMSIS_DIR)/CM3/CoreSupport),)
else
INCLUDES += -I$(CMSIS_DIR)/CM3/CoreSupport
endif

CFLAGS += $(INCLUDES)
EXTRA_DEFS ?= -DSTM32F10X_MD -DUSE_STDPERIPH_DRIVER
CFLAGS += $(EXTRA_DEFS)

# Cross-platform commands
ifeq ($(OS),Windows_NT)
MKDIR_CMD = powershell -Command "if (-not (Test-Path -Path '$(BUILD_DIR)')) { New-Item -ItemType Directory -Path '$(BUILD_DIR)' | Out-Null }"
RM_CMD = powershell -Command "Remove-Item -Recurse -Force '$(BUILD_DIR)' -ErrorAction SilentlyContinue; Remove-Item -Force '$(PROJECT).elf','$(PROJECT).bin','$(PROJECT).map' -ErrorAction SilentlyContinue; exit 0"
COPY_OUT_CMD = powershell -Command "if (Test-Path '$(BIN)') { Copy-Item -Path '$(BIN)' -Destination '.' -Force }; if (Test-Path '$(ELF)') { Copy-Item -Path '$(ELF)' -Destination '.' -Force }; exit 0"
else
MKDIR_CMD = mkdir -p $(BUILD_DIR)
COPY_CMD = cp $(OBJS) $(BUILD_DIR)/ 2>/dev/null || true; cp $(PROJECT).bin $(BUILD_DIR)/
RM_CMD = rm -rf $(BUILD_DIR) $(PROJECT).elf $(PROJECT).bin $(PROJECT).map
COPY_OUT_CMD = cp $(BIN) $(ELF) . 2>/dev/null || true
endif


# final ELF/BIN paths inside build
ELF := $(BUILD_DIR)/$(PROJECT).elf
BIN := $(BUILD_DIR)/$(PROJECT).bin

all: $(BIN) copyout

.PHONY: copyout
copyout: $(BIN)
	@$(COPY_OUT_CMD)

# Compile C -> .o (write objects to build/ mirroring source path)
$(BUILD_DIR)/%.o: %.c
ifeq ($(OS),Windows_NT)
	@powershell -Command "if (-not (Test-Path -Path '$(@D)')) { New-Item -ItemType Directory -Path '$(@D)' | Out-Null }"
else
	@mkdir -p $(@D)
endif
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble .s -> .o
$(BUILD_DIR)/%.o: %.s
ifeq ($(OS),Windows_NT)
	@powershell -Command "if (-not (Test-Path -Path '$(@D)')) { New-Item -ItemType Directory -Path '$(@D)' | Out-Null }"
else
	@mkdir -p $(@D)
endif
	$(CC) $(MCU_FLAGS) -c $< -o $@

# Object list in build/ (mirror source paths)
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS)) $(BUILD_DIR)/$(STARTUP:.s=.o)

# Link (produce ELF inside build)
$(ELF): $(OBJS) $(LD_SCRIPT)
	@$(MKDIR_CMD)
	$(CC) $(LDFLAGS) $(OBJS) -T $(LD_SCRIPT) -o $@

# Bin (inside build)
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

map: $(ELF)
	$(OBJDUMP) -h $< > $(BUILD_DIR)/$(PROJECT).map

flash: $(BIN)
	openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c "program $(BIN) 0x08000000 verify reset exit"

clean:
	-@$(RM_CMD)

.PHONY: all clean flash map
