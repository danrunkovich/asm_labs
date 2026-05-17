# Переопределяем стандартное правило, чтобы использовать NASM вместо GNU as

#По умолчанию - по возрастанию
ORDER ?= ASC

# Транслируем ORDER → NASM-флаг
ifeq ($(ORDER), DESC)
    ORDER_FLAGS += -DORDER_DESC #ORDER=DESC
endif

# Инструменты и флаги
ASM       = nasm
ASMFLAGS  = -f elf64 -g          # -g для отладочной информации
LD        = ld
LDFLAGS   =                      # опциональные флаги линковки

# Имя исполняемого файла и исходный код (можно изменить под ваш файл)
TARGET    = lab2
SOURCES   = lab2.s               # исходник с Intel-синтаксисом
OBJECTS   = $(SOURCES:.s=.o)     # автоматическая замена .s на .o

# Цель по умолчанию
all: $(TARGET)

# Линковка объектного файла
$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) $^ -o $@

# Компиляция .s -> .o через NASM (переопределяем встроенное правило)
%.o: %.s
	$(ASM) $(ASMFLAGS) $(ORDER_FLAGS) $< -o $@

# Очистка
clean:
	rm -f $(OBJECTS) $(TARGET)

# Запуск отладчика (сборка + gdb)
debug: $(TARGET)
	gdb -tui $(TARGET)
