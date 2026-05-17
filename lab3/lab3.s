; системные вызовы которые я буду юзать в данной лабе
;
; 0 - чтение
; rdi - файловый дескривтор :
;   0 - stdin
;   1 - stdout
;   2 - stderror
; rsi - адрес буфера куда будет просиходить чтение
; rdx - размер буфера
; в rax лежит после системного вызова количество прочитанных байт
;
; 1 - запись
; rdi - файловый дескриптор (он у меня будет хранится в переменной
; file_descriptor после открытия файла, имя которого мне вводят с входного потока)
; rsi - адрес буфера откуда будет происходить запись в файл или выходной поток
; rdx - размер буфера
; в rax после системного вызова будет лежать количество записанных байт
;
; 2 - открытие файла
; rdi - буффер с именем файла
; rsi - флаги
;   в моем случае я буду использовать следующие флаги:
;       1 - только запись (еще есть 0 - только чтение и 2 - чтение + запись)
;       0x40 = 64 - при необходимости создать файл
;       0x400 = 1024 - запись только в конец файла
;   флаги комбинируются для системного вызова при помощи логиского ИЛИ (1 | 64 | 1024)
; rdx - права доступа (0o644, но будет игнорироваться если файл уже существует)
; в rax лежит файловый дескриптор после открытия файла
; потом этот же файловый дескриптор буду юзать для остальных работ с файлом
;
; 3 - закрытие файла
; rdi - файловый дексриптор
; в rax потом лежит 0
;
; 60 - конец проограммы
; rdi - код ошибки от 0 до 255
;
; также надо учитывать что если в системный вызов передается строка то она должна оканчиваться нуль-байтом
; еще надо все целочиселнные аргументы для системного вызова передавать в 32-битном формате но я на это забил



section .bss

    input_buffer resb 256 ; буфер для чтения строк из stdin
    input_len resq 1 ; количество прочитанных байт

    output_buffer resb 256 ; буфер для результирующей строки
    output_len resq 1 ; длина результата (используется внутри процедур)

    file_descriptor resq 1 ; файловый дескриптор открытого файла

section .rodata
    input_str_msg db "~~Input the string for processing~~", 10, 0
    str_msg_len equ $ - input_str_msg

section .text
global _start

string_process:
    push rbp
    mov  rbp, rsp
    push rbx ; bl = first_char текущего слова
    push r12 ; r12b = временный символ
    push r13 ; r13 = флаг «было ли уже хоть одно слово» (0/1)
    ; нужен чтобы не ставить пробел перед первым словом
    push r14 ; r14 = индекс чтения  во входном буфере
    push r15 ; r15 = индекс записи в выходном буфере

    xor r14, r14 ; read_idx  = 0
    xor r15, r15 ; write_idx = 0
    xor r13, r13 ; first_word_seen = false (0)

    .main_loop:
        cmp  r14, qword [rsi]   ; read_idx >= input_len ?
        jge  .main_done

        movzx eax, byte [rdi + r14]  ; al = текущий символ
        inc   r14

        cmp   al, 32    ; пробел
        je    .skip_sep
        cmp   al, 9     ; tab
        je    .skip_sep
        cmp   al, 10    ; '\n' — конец строки внутри блока
        je    .main_done
        cmp   al, 13    ; '\r'
        je    .skip_sep

        ; eсли уже было слово — ставим пробел-разделитель перед текущим
        test  r13, r13
        jz    .no_space_before
        mov   byte [rdx + r15], 32
        inc   r15
    .no_space_before:
        mov   r13, 1 ; отмечаем: первое слово встречено

        ; Первый символ слова — сохраняем как first_char в bl
        mov   bl, al               ; bl = first_char
        mov   byte [rdx + r15], al ; копируем его в output
        inc   r15

        .word_loop:
            cmp  r14, qword [rsi]
            jge  .main_done        ; конец буфера прямо посреди слова

            movzx eax, byte [rdi + r14]
            inc   r14

            cmp  al, 32   ; пробел → слово закончилось
            je   .word_done
            cmp  al, 9    ; tab → слово закончилось
            je   .word_done
            cmp  al, 10   ; '' → строка закончилась
            je   .line_end_from_word
            cmp  al, 13
            je   .word_done

            ; Символ принадлежит слову
            cmp  al, bl              ; совпадает с first_char?
            je   .word_loop          ; да — пропускаем (дубль удалён)

            ; нет — копируем в output
            mov  byte [rdx + r15], al
            inc  r15
            jmp  .word_loop

        .line_end_from_word:
            jmp .main_done

        .word_done:
            jmp .main_loop

    .skip_sep:
        jmp .main_loop

    .main_done:
        ; сейвим длину результата
        mov  qword [rcx], r15

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret


input_str_process:
    push rbp
    mov  rbp, rsp

    mov  rax, 1
    mov  rdi, 1
    mov  rsi, input_str_msg
    mov  rdx, str_msg_len
    syscall

    mov  rax, 0
    mov  rdi, 0
    mov  rsi, input_buffer
    mov  rdx, 256
    syscall
    ; rax = прочитанные байты; 0 = EOF (Ctrl+D)

    mov  rsp, rbp
    pop  rbp
    ret


open_file_process:
    push rbp
    mov  rbp, rsp

    ; rdi уже содержит адрес имени файла (передан снаружи)
    mov  rax, 2
    mov  rsi, 1 | 64 | 1024
    mov  rdx, 0o644
    syscall

    mov  qword [file_descriptor], rax

    mov  rsp, rbp
    pop  rbp
    ret


output_str_process:
    push rbp
    mov  rbp, rsp

    mov  rax, 1
    mov  rdi, qword [file_descriptor]
    mov  rsi, output_buffer
    ; rdx уже содержит длину (передана снаружи)
    syscall

    mov  rsp, rbp
    pop  rbp
    ret


close_file_process:
    push rbp
    mov  rbp, rsp

    mov  rax, 3
    mov  rdi, qword [file_descriptor]
    syscall

    mov  rsp, rbp
    pop  rbp
    ret



_start:
    mov  r15, [rsp + 16] ; r15 = указатель на имя файла

    ; если argc < 2 --> ошибка
    cmp  qword [rsp], 2
    jl   .error_no_arg

    ; передаём указатель на имя в rdi
    mov  rdi, r15
    call open_file_process

    ; если дескриптор < 0 — ошибка открытия файла
    cmp  qword [file_descriptor], 0
    jl   .error_open

    .read_loop:
        call input_str_process ; выводит приглашение, читает блок stdin
        ; rax = кол-во прочитанных байт

        cmp  rax, 0
        je   .eof ; rax == 0 (Ctrl+D) --> завершаем

        mov  r14, rax ; r14 = полный размер прочитанного блока
        xor  rbx, rbx ; rbx = текущее смещение внутри input_buffer (откуда начинается следующая необработанная строка)

        .line_loop:
            ; дошли ли до конца блока
            cmp  rbx, r14
            jge  .read_loop ; блок исчерпан — читаем следующий

            mov  rax, r14
            sub  rax, rbx ; rax = байт от rbx до конца блока
            mov  qword [input_len], rax ; string_process прочитает это

            ; rdi = адрес начала текущей строки в input_buffer
            ; rsi = адрес [input_len] (строка = байты до или до [rsi] байт)
            ; rdx = output_buffer
            ; rcx = адрес [output_len] — куда запишем длину результата
            lea  rdi, [input_buffer + rbx]
            lea  rsi, [input_len]
            mov  rdx, output_buffer
            mov  rcx, output_len
            call string_process
            ; Теперь [output_len] = длина обработанной строки (без '\n')

            mov  rax, qword [output_len]
            mov  byte [output_buffer + rax], 10
            inc  rax

            mov  rdx, rax
            call output_str_process

            ; yаходим позицию '\n' в исходном блоке начиная с rbx,
            ; чтобы сдвинуть rbx на начало next строки.
            .find_next_line:
                cmp  rbx, r14 ; вышел ли я за конец блока
                jge  .read_loop
                cmp  byte [input_buffer + rbx], 10
                je   .found_newline
                inc  rbx
                jmp  .find_next_line
            .found_newline:
                inc  rbx ; rbx = начало следующей строки
            jmp  .line_loop

    .eof:
        call close_file_process

    .ok:
        mov  rax, 60
        xor  rdi, rdi
        syscall

    .error_no_arg:
        ; Не передан аргумент командной строки
        mov  rax, 60
        mov  rdi, 2
        syscall

    .error_open:
        ; Не удалось открыть файл
        mov  rax, 60
        mov  rdi, 1
        syscall
