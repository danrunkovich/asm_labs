CC = gcc
NASM = nasm

# Настройки по умолчанию
OPT ?= -O0
USE_IMPL ?= C

# Флаги компиляции
CFLAGS = -Wall -Wextra -I./src $(OPT) -DOPT_FLAGS="\"$(OPT)\""
NASMFLAGS = -f elf64
LDFLAGS = -lm

SRC_DIR = src
# Директория для объектов зависит от конфигурации (C/ASM + оптимизация)
CONFIG_NAME = $(USE_IMPL)_$(subst -,,$(OPT))
OBJ_DIR = obj/$(CONFIG_NAME)

HEADERS = $(SRC_DIR)/process/proc.h
TARGET = lab5

# Выбор файлов в зависимости от реализации
ifeq ($(USE_IMPL), ASM_S)
    CFLAGS += -DUSE_ASM_S
    OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/proc_scalar.o
else ifeq ($(USE_IMPL), ASM_V)
    CFLAGS += -DUSE_ASM_V
    OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/proc_vector.o
else
    OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/proc_c.o
endif

.PHONY: all clean dirs

all: dirs $(TARGET)

dirs:
	mkdir -p $(OBJ_DIR)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $^ -o $(TARGET) $(LDFLAGS)

$(OBJ_DIR)/main.o: $(SRC_DIR)/main.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/proc_c.o: $(SRC_DIR)/process/C/proc.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/proc_scalar.o: $(SRC_DIR)/process/ASM_S/proc_scalar.s
	$(NASM) $(NASMFLAGS) $< -o $@

$(OBJ_DIR)/proc_vector.o: $(SRC_DIR)/process/ASM_V/proc_vector.s
	$(NASM) $(NASMFLAGS) $< -o $@

clean:
	rm -rf obj $(TARGET)
