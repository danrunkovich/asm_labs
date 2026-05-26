section .text
global process_image_asm_vector

; void process_image_asm_vector(const unsigned char* src, unsigned char* dst, int width, int height)
; Параметры:
;   rdi = src
;   rsi = dst
;   rdx = width
;   rcx = height

process_image_asm_vector:
    push rbp
    mov rbp, rsp

    ; Сохраняем callee-saved регистры
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Сохраняем ширину и высоту
    mov r8, rdx         ; r8 = width
    mov r15, rcx        ; r15 = height

    ; Очистка целевого буфера dst
    mov rax, r8
    imul rax, r15       ; rax = общее кол-во пикселей
    test rax, rax
    jz .done

    xor r10, r10
.clear_loop:
    mov byte [rsi + r10], 0
    inc r10
    cmp r10, rax
    jl .clear_loop

    ; Внешний цикл от y = 1 до height - 2
    mov r14, 1          ; r14 = y

.outer_loop:
    mov rax, r15
    dec rax             ; rax = height - 1
    cmp r14, rax        ; сравниваем y с height - 1
    jge .done

    ; Предвычисление смещений строк (row-offsets)
    mov r13, r14
    imul r13, r8        ; r13 = y * width

    mov r12, r13
    sub r12, r8         ; r12 = (y - 1) * width

    mov rbx, r13
    add rbx, r8         ; rbx = (y + 1) * width

    ; Превращаем смещения строк в абсолютные указатели в памяти src (прибавляя rdi)
    add r12, rdi        ; r12 = src + (y - 1) * width
    add r13, rdi        ; r13 = src + y * width
    add rbx, rdi        ; rbx = src + (y + 1) * width

    ; Вычисляем абсолютный указатель на строку записи в dst (rsi + y * width) в r11
    mov r11, r14
    imul r11, r8
    add r11, rsi        ; r11 = dst + y * width

    ; Внутренний цикл: x начинается с 1
    mov r9, 1           ; r9 = x

    pxor xmm15, xmm15   ; xmm15 = 0 (используется для распаковки байт в слова)

.inner_vector_loop:
    ; Защитная проверка ширины для обработки 8 пикселей за раз: (width - 1) - 8 = width - 9
    mov rax, r8
    sub rax, 9
    cmp r9, rax
    jg .inner_scalar_tail

    ; --- Загрузка и распаковка Row 0 (байт в 16-битные знаковые слова) ---
    movq xmm0, [r12 + r9 - 1]     ; v00 (загружаем 8 байт)
    punpcklbw xmm0, xmm15

    movq xmm1, [r12 + r9]         ; v01 (загружаем 8 байт со сдвигом)
    punpcklbw xmm1, xmm15

    movq xmm2, [r12 + r9 + 1]     ; v02
    punpcklbw xmm2, xmm15

    ; --- Загрузка и распаковка Row 1 ---
    movq xmm3, [r13 + r9 - 1]     ; v10
    punpcklbw xmm3, xmm15

    movq xmm4, [r13 + r9 + 1]     ; v12
    punpcklbw xmm4, xmm15

    ; --- Загрузка и распаковка Row 2 ---
    movq xmm5, [rbx + r9 - 1]     ; v20
    punpcklbw xmm5, xmm15

    movq xmm6, [rbx + r9]         ; v21
    punpcklbw xmm6, xmm15

    movq xmm7, [rbx + r9 + 1]     ; v22
    punpcklbw xmm7, xmm15

    ; --- Свертка по горизонтали Sobel X ---
    ; gx = -v00 + v02 - 2*v10 + 2*v12 - v20 + v22
    movdqa xmm8, xmm2                   ; gx = v02
    psubw xmm8, xmm0                    ; gx -= v00

    movdqa xmm10, xmm4
    psllw xmm10, 1                      ; умножение на 2 сдвигом влево на 1 бит
    paddw xmm8, xmm10                   ; gx += 2 * v12

    movdqa xmm10, xmm3
    psllw xmm10, 1
    psubw xmm8, xmm10                   ; gx -= 2 * v10

    paddw xmm8, xmm7                    ; gx += v22
    psubw xmm8, xmm5                    ; gx -= v20

    ; --- Свертка по вертикали Sobel Y ---
    ; gy = -v00 - 2*v01 - v02 + v20 + 2*v21 + v22
    movdqa xmm9, xmm5                   ; gy = v20
    paddw xmm9, xmm7                    ; gy += v22

    movdqa xmm10, xmm6
    psllw xmm10, 1
    paddw xmm9, xmm10                   ; gy += 2 * v21

    psubw xmm9, xmm0                    ; gy -= v00
    psubw xmm9, xmm2                    ; gy -= v02

    movdqa xmm10, xmm1
    psllw xmm10, 1
    psubw xmm9, xmm10                   ; gy -= 2 * v01

    ; --- Быстрый безветвистый Abs для gx (xmm8) ---
    movdqa xmm11, xmm8
    psraw xmm11, 15                     ; заполнение знаковым битом
    pxor xmm8, xmm11
    psubw xmm8, xmm11

    ; --- Быстрый безветвистый Abs для gy (xmm9) ---
    movdqa xmm12, xmm9
    psraw xmm12, 15                     ; заполнение знаковым битом
    pxor xmm9, xmm12
    psubw xmm9, xmm12

    ; --- Вычисление мощности градиента ---
    paddw xmm8, xmm9                    ; xmm8 = abs(gx) + abs(gy)

    ; --- Насыщение и сжатие в байты (Clamping back to 8-bit unsigned) ---
    packuswb xmm8, xmm15                ; автоограничение сверху (значения > 255 сжимаются до 255)

    ; --- Запись полученных 8 байт напрямую в dst буфер ---
    movq [r11 + r9], xmm8

    add r9, 8                           ; переходим к следующим 8 пикселям
    jmp .inner_vector_loop

.inner_scalar_tail:
    mov rax, r8
    dec rax                             ; rax = width - 1
    cmp r9, rax
    jge .outer_loop_next

    ; --- Скалярный Fallback для правого некратного края строки (используем только r10 как временный) ---
    movzx r10, byte [r12 + r9 - 1]    ; g00
    mov rax, r10
    neg rax                                  ; gx = -g00
    mov rcx, r10
    neg rcx                                  ; gy = -g00

    movzx r10, byte [r12 + r9]        ; g01
    shl r10, 1
    sub rcx, r10

    movzx r10, byte [r12 + r9 + 1]    ; g02
    add rax, r10
    sub rcx, r10

    movzx r10, byte [r13 + r9 - 1]    ; g10
    shl r10, 1
    sub rax, r10

    movzx r10, byte [r13 + r9 + 1]    ; g12
    shl r10, 1
    add rax, r10

    movzx r10, byte [rbx + r9 - 1]    ; g20
    sub rax, r10
    add rcx, r10

    movzx r10, byte [rbx + r9]        ; g21
    shl r10, 1
    add rcx, r10

    movzx r10, byte [rbx + r9 + 1]    ; g22
    add rax, r10
    add rcx, r10

    ; Abs(gx)
    mov rdx, rax
    sar rdx, 63
    xor rax, rdx
    sub rax, rdx

    ; Abs(gy)
    mov rdx, rcx
    sar rdx, 63
    xor rcx, rdx
    sub rcx, rdx

    add rax, rcx ; итоговая интенсивность

    cmp rax, 255
    jle .no_clamp_scalar
    mov rax, 255
.no_clamp_scalar:

    ; r11 хранит абсолютный указатель на строку dst
    mov [r11 + r9], al
    inc r9
    jmp .inner_scalar_tail

.outer_loop_next:
    inc r14
    jmp .outer_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret
