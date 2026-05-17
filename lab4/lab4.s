; для представления вещественных числе юзается стандапрт IEEE 754-2008
; я юзаю в данной лабе вещественные числа двойной точности :
;   порядок : 10^(-308) <= x < 10^(308)
;   занимает 64 бита (1 под знак, 52 под мантиссу, 11 под порядок)
;   точность 15-16 знаков после запятой



section .bss
    file_ptr resq 1 ; FILE* для выходного файла
    precision resq 1 ; точность вычисления (double)
    arg resq 1 ; аргумент функции (double)
    res resq 1 ; результат из библиотеки C (acos)
    my_res resq 1 ; результат нашего ряда

section .rodata
    file_mode db "w", 0
    fmt_double db "%lf", 0         ; формат scanf для double
    half_pi dq 1.5707963267948966  ; pi/2
    neg_one dq -1.0
    pos_one dq  1.0
    const_zero dq  0.0
    const_two dq  2.0

    input_arg_msg db "Введите аргумент функции ~~> ", 0
    input_per_msg db "Введите точность вычисления ряда ~~> ", 0

    input_file_name_error_msg db "Ошибка!!! Введите имя файла параметром командной строки", 10, 0
    open_file_error_msg db "Ошибка при открытии файла :(", 10, 0
    close_file_error_msg db "Ошибка при закрытии файла :(", 10, 0
    out_of_range_msg db "ОШИБКА: аргумент x должен быть в диапазоне [-1; 1]", 10, 0
    invalid_arg_msg db "ОШИБКА: неверный формат ввода аргумента", 10, 0
    invalid_per_msg db "ОШИБКА: неверный формат ввода точности", 10, 0


    fmt_member db "%d %.15lf", 10, 0

    my_result_msg db "Результат (мой ряд) для x = %.15lf -> arccos(x) = %.15lf", 10, 0
    lib_result_msg db "Результат (библиотека C) для x = %.15lf -> arccos(x) = %.15lf", 10, 0

section .text
global main

extern printf
extern scanf
extern acos
extern fopen
extern fclose
extern fprintf
extern exit

print_error:
    push rbp
    mov  rbp, rsp
    and  rsp, -16 ; выравниваем стек по 16 байт
    xor  eax, eax ; нет xmm аргументов
    call printf
    mov  rsp, rbp
    pop  rbp
    ret





input_val:
    push rbp
    mov  rbp, rsp

    push rbx
    push r12
    ; сохраняем указатель на буфер для scanf (rsi) в r12 (callee-saved)
    mov  r12, rsi

    ; rdi уже содержит строку-приглашение
    xor  eax, eax ; нет xmm аргументов у printf здесь
    call printf

    lea  rdi, [fmt_double]
    mov  rsi, r12 ; восстанавливаем указатель на буфер
    xor  eax, eax
    call scanf
    ; rax = кол-во успешно считанных полей (1 = успех)

    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret

my_acos:
    push rbp
    mov  rbp, rsp

    push rbx
    push r12
    push r13
    sub rsp, 88 ; rsp = rbp - 112, кратно 16 пушка

    ; cохраняем оригинальные xmm6 ... xmm11 вызывающего
    movsd [rbp - 40], xmm6
    movsd [rbp - 48], xmm7
    movsd [rbp - 56], xmm8
    movsd [rbp - 64], xmm9
    movsd [rbp - 72], xmm10
    movsd [rbp - 80], xmm11

    movsd xmm6, [arg] ; xmm6  = x
    movsd xmm7, [precision] ; xmm7  = precision

    ; xmm8  = t_n (текущий член ряда, t_0 = x)
    movsd xmm8, xmm6

    ; xmm9  = x^2
    movsd xmm9, xmm6
    mulsd xmm9, xmm9

    ; xmm10 = sum (сумма arcsin)
    xorpd xmm10, xmm10

    ; r12 = n (индкс текущего члена ряда, начинаем с 0)
    xor  r12, r12

    movsd xmm10, xmm8 ; sum = x

    movsd [rbp - 88], xmm8 ; t_n
    movsd [rbp - 96], xmm9 ; x^2
    movsd [rbp - 104], xmm10 ; sum
    movsd [rbp - 112], xmm7 ; precision

    mov  rdi, [file_ptr]
    lea  rsi, [fmt_member]
    mov  rdx, r12 ; n = 0
    movsd xmm0, xmm8
    mov  eax, 1
    call fprintf

    movsd xmm8, [rbp - 88]
    movsd xmm9, [rbp - 96]
    movsd xmm10, [rbp - 104]
    movsd xmm7, [rbp - 112]

    inc  r12 ; n = 1

.loop:

    ; t_n = t_{n-1} * x^2 * (2n-1)^2 / (2n*(2n+1))

    ; rax = 2n - 1
    mov  rax, r12
    add  rax, rax
    dec  rax

    ; числитель (2n-1)^2 -> xmm11
    cvtsi2sd xmm11, rax
    mulsd    xmm11, xmm11

    ; знаменатель 2n * (2n+1) -> xmm0
    mov  rax, r12
    add  rax, rax
    cvtsi2sd xmm0, rax ; double(2n)
    inc  rax
    cvtsi2sd xmm1, rax ; double(2n+1)
    mulsd xmm0, xmm1 ; 2n*(2n+1)

    ; t_n = t_{n-1} * x^2 * (2n-1)^2 / (2n*(2n+1))
    mulsd xmm8, xmm9 ; t *= x^2
    mulsd xmm8, xmm11 ; t *= (2n-1)^2
    divsd xmm8, xmm0 ; t /= 2n*(2n+1)

    ; |t_n|: зануляем знаковый бит маской 0x7FFFFFFFFFFFFFFF
    mov  rax, 0x7FFFFFFFFFFFFFFF
    movq xmm0, rax ; xmm0 = маска
    movsd xmm1, xmm8
    andpd xmm1, xmm0 ; xmm1 = |t_n|

    ucomisd xmm1, xmm7 ; |t_n| < precision
    jb .loop_done

    ; записываем в файл
    movsd [rbp - 88], xmm8
    movsd [rbp -96], xmm9
    movsd [rbp - 104], xmm10
    movsd [rbp - 112], xmm7

    mov  rdi, [file_ptr]
    lea  rsi, [fmt_member]
    mov  rdx, r12
    movsd xmm0, xmm8
    mov  eax, 1
    call fprintf

    movsd xmm8,  [rbp - 88]
    movsd xmm9,  [rbp - 96]
    movsd xmm10, [rbp - 104]
    movsd xmm7,  [rbp - 112]

    addsd xmm10, xmm8

    inc  r12
    jmp  .loop

.loop_done:
    movsd xmm0, [half_pi]
    subsd xmm0, xmm10
    movsd [my_res], xmm0

    ; восстанавливаем оригинальные xmm6..xmm11
    movsd xmm6, [rbp - 40]
    movsd xmm7, [rbp - 48]
    movsd xmm8, [rbp - 56]
    movsd xmm9, [rbp - 64]
    movsd xmm10, [rbp - 72]
    movsd xmm11, [rbp - 80]

    add  rsp, 88
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8

    mov r12, rdi ; r12 = argc
    mov r13, rsi ; r13 = argv

    ; проверяем наличие имени файла (т е argc >= 2)
    cmp  r12, 2
    jl .error_input_file_name


    mov rdi, [r13 + 8] ; argv[1] = имя файла
    lea rsi, [file_mode]
    call fopen
    test rax, rax
    jz .error_open_file
    mov [file_ptr], rax

    lea rdi, [input_arg_msg]
    lea rsi, [arg]
    call input_val
    cmp eax, 1
    jne .error_invalid_arg

    movsd xmm0, [arg]
    movsd xmm1, [pos_one]
    ucomisd xmm0, xmm1
    ja .error_out_of_range ; x > 1

    movsd xmm1, [neg_one]
    ucomisd xmm0, xmm1
    jb .error_out_of_range ; x < -1


    lea  rdi, [input_per_msg]
    lea  rsi, [precision]
    call input_val
    cmp  eax, 1
    jne .error_invalid_per

    call my_acos

    movsd xmm0, [arg]
    call  acos ; результат в xmm0
    movsd [res], xmm0


    lea  rdi, [my_result_msg]
    movsd xmm0, [arg]
    movsd xmm1, [my_res]
    mov  eax, 2
    call printf


    lea  rdi, [lib_result_msg]
    movsd xmm0, [arg]
    movsd xmm1, [res]
    mov  eax, 2
    call printf


    mov rdi, [file_ptr]
    call fclose
    cmp eax, 0
    jne .error_close_file

    jmp .end


.error_close_file:
    lea  rdi, [close_file_error_msg]
    call print_error
    jmp  .end

.error_open_file:
    lea rdi, [open_file_error_msg]
    call print_error
    jmp .end

.error_out_of_range:
    ; зкрываем файл перед выходом, если он был открыт
    mov rdi, [file_ptr]
    test rdi, rdi
    jz .skip_close_range
    call fclose
.skip_close_range:
    lea rdi, [out_of_range_msg]
    call print_error
    jmp .end

.error_invalid_arg:
    mov rdi, [file_ptr]
    test rdi, rdi
    jz .skip_close_inv_arg
    call fclose
.skip_close_inv_arg:
    lea rdi, [invalid_arg_msg]
    call print_error
    jmp .end

.error_invalid_per:
    mov  rdi, [file_ptr]
    test rdi, rdi
    jz   .skip_close_inv_per
    call fclose
    .skip_close_inv_per:
    lea  rdi, [invalid_per_msg]
    call print_error
    jmp  .end

.error_input_file_name:
    lea  rdi, [input_file_name_error_msg]
    call print_error
    jmp  .end

.end:
    xor  eax, eax ; возвращаем 0 (успех)
    add  rsp, 8
    pop  r13
    pop  r12
    pop  rbx
    mov  rsp, rbp
    pop  rbp
    ret
