CC = gcc
NASM = nasm

# Настройки по умолчанию
OPT ?= -O0
USE_IMPL ?= C

# Флаги компиляции
# -DOPT_FLAGS передает строку с флагами в main.c для логирования
CFLAGS = -Wall -Wextra -I./src $(OPT) -DOPT_FLAGS="\"$(OPT)\""
NASMFLAGS = -f elf64
LDFLAGS = -lm

SRC_DIR = src
# Директория для объектов зависит от конфигурации (реализация + оптимизация),
# чтобы файлы разных сборок не перемешивались.
CONFIG_NAME = $(USE_IMPL)_$(subst -,,$(OPT))
OBJ_DIR = obj/$(CONFIG_NAME)
TIMING_DIR = timing

HEADERS = $(SRC_DIR)/process/proc.h
TARGET = lab5

# Выбор файлов и флагов в зависимости от реализации
ifeq ($(USE_IMPL), ASM)
    CFLAGS += -DUSE_ASM
    OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/proc_asm.o
else
    OBJS = $(OBJ_DIR)/main.o $(OBJ_DIR)/proc_c.o
endif

.PHONY: all clean dirs

all: dirs $(TARGET)

# Создание необходимых папок
dirs:
	mkdir -p $(OBJ_DIR)
	mkdir -p $(TIMING_DIR)

# Сборка исполняемого файла
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $^ -o $(TARGET) $(LDFLAGS)

# Компиляция основного файла
$(OBJ_DIR)/main.o: $(SRC_DIR)/main.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Компиляция реализации на C
$(OBJ_DIR)/proc_c.o: $(SRC_DIR)/process/C/proc.c $(HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@

# Компиляция реализации на ассемблере
$(OBJ_DIR)/proc_asm.o: $(SRC_DIR)/process/ASM/proc.s
	$(NASM) $(NASMFLAGS) $< -o $@

clean:
	rm -rf obj $(TARGET)
