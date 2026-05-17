TARGET = lab4
SRC = lab4.s
OBJ = lab4.o

# Инструменты
AS = nasm
ASFLAGS = -f elf64
LD = ld

# --- ПОИСК СИСТЕМНЫХ ПУТЕЙ ---
# Мы используем возможности gcc, чтобы узнать, где лежат нужные файлы в вашей системе
# CRT (C runtime) объукты
LIBC_PATH = $(shell gcc -print-file-name=libc.so) # libc.so - файл библиотеки C (там реализованы все используемые мной функции)
CRT1 = $(shell gcc -print-file-name=crt1.o) # ctr1.o (C runtime 1) - файл в котором объявлена метка _start
# которую линкер ld ищет при сборке проекта
CRTI = $(shell gcc -print-file-name=crti.o) # ctri.o (C runtime begin) - файл в котором написан пролог для программы
# то есть там объявлены секции .init (с инициализацией) и .fini (с финиализацией). Они нужны для корректной работы
# конструкторов и деструкторов даже если их нет в программе
CRTN = $(shell gcc -print-file-name=crtn.o) # ctrn.o (C runtime end) - файл с завершением тех секций .init и .fini
DYNAMIC_LINKER = /lib64/ld-linux-x86-64.so.2 # файл (точнее даже программа) которая подлеючает в проект библиотечные функции
# языка С из libc.so (без --dynamic-linker выполнение программы завершится sigfault'ом)

# Флаги линковки
# -e main: устанавливаем точку входа (хотя crt1.o по умолчанию ждет _start)
# -lc: подключаем libc.so (библиотека C)
# -lm: подключаем libm.so (математическая библиотека для acos)
LDFLAGS = -dynamic-linker $(DYNAMIC_LINKER) \
          $(CRT1) $(CRTI) \
          $(OBJ) \
          -lc -lm \
          $(CRTN)

all: $(TARGET)

$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) $< -o $@

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@

clean:
	rm -f $(OBJ) $(TARGET)
	rm *.txt

.PHONY: all clean
