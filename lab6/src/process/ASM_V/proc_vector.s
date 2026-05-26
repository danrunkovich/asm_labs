section .text
global process_image_asm_vector

; void process_image_asm_vector (const unsigned char* src, unsigned char* dst, const int width, const int height)
;   rdi = src (исходное полутоновое изображение)
;   rsi = dst (буфер результата)
;   rdx = width
;   rcx = height

process_image_asm_vector:
    push rbp
    mov rbp, rsp

    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Переносим ширину и высоту в регистры
    mov r8, rdx ; r8 = width
    mov r15, rcx ; r15 = height

    mov rax, r8
    imul rax, r15 ; rax = total pixels
    test rax, rax
    jz .done

    xor r10, r10
.clear_loop:
    mov byte [rsi + r10], 0
    inc r10
    cmp r10, rax
    jl .clear_loop

    ; Внешний цикл по строкам: y от 1 до height - 2
    mov r14, 1 ; r14 = y

.outer_loop:
    mov rax, r15
    dec rax ; rax = height - 1
    cmp r14, rax ; Сравниваем y с границей
    jge .done

    mov r13, r14
    imul r13, r8 ; r13 = y * width

    mov r12, r13
    sub r12, r8 ; r12 = (y - 1) * width (верхняя строчка)

    mov rbx, r13
    add rbx, r8 ; rbx = (y + 1) * width (нижняя строчка)

    mov r9, 1; r9 = x

    vpxor ymm15, ymm15, ymm15 ; ymm15 = 0 для очистки

.inner_vector_loop:
    ; за один проход берем 16 пикселей.
    ; Безопасная граница справа: (width - 1) - 16 = width - 17
    mov rax, r8
    sub rax, 17
    cmp r9, rax
    jg .inner_scalar_tail

    ; строка 0 (y - 1)
    vpmovzxbw ymm0, [rdi + r12 + r9 - 1] ; v00 (загружает 16 байт и расширяет до 16 слов)
    vpmovzxbw ymm1, [rdi + r12 + r9] ; v01
    vpmovzxbw ymm2, [rdi + r12 + r9 + 1] ; v02

    ; строка 1 (y)
    vpmovzxbw ymm3, [rdi + r13 + r9 - 1] ; v10
    vpmovzxbw ymm4, [rdi + r13 + r9 + 1] ; v12

    ; строка 2 (y + 1)
    vpmovzxbw ymm5, [rdi + rbx + r9 - 1] ; v20
    vpmovzxbw ymm6, [rdi + rbx + r9] ; v21
    vpmovzxbw ymm7, [rdi + rbx + r9 + 1] ; v22

    ; gx = -v00 + v02 - 2*v10 + 2*v12 - v20 + v22
    vpsubw ymm8, ymm2, ymm0 ; gx = v02 - v00

    vpsllw ymm10, ymm4, 1
    vpaddw ymm8, ymm8, ymm10 ; gx += 2 * v12

    vpsllw ymm10, ymm3, 1
    vpsubw ymm8, ymm8, ymm10 ; gx -= 2 * v10

    vpaddw ymm8, ymm8, ymm7 ; gx += v22
    vpsubw ymm8, ymm8, ymm5 ; gx -= v20

    ; gy = -v00 - 2*v01 - v02 + v20 + 2*v21 + v22
    vpaddw ymm9, ymm5, ymm7 ; gy = v20 + v22

    vpsllw ymm10, ymm6, 1
    vpaddw ymm9, ymm9, ymm10 ; gy += 2 * v21

    vpsubw ymm9, ymm9, ymm0 ; gy -= v00
    vpsubw ymm9, ymm9, ymm2 ; gy -= v02

    vpsllw ymm10, ymm1, 1
    vpsubw ymm9, ymm9, ymm10 ; gy -= 2 * v01

    vpabsw ymm8, ymm8 ; ymm8 = abs(gx)
    vpabsw ymm9, ymm9 ; ymm9 = abs(gy)

    vpaddw ymm8, ymm8, ymm9 ; ymm8 = abs(gx) + abs(gy)

    ; --- Упаковка с насыщением (Word -> Byte) ---
    vpackuswb ymm8, ymm8, ymm15 ; Сжимает слова в байты, ограничивая значения больше 255 до 255.
    ; Из-за in-lane архитектуры данные лежат в блоках [0-63] и [128-191] битах.

    ; Извлекаем верхний 128-битный блок во вспомогательный XMM-регистр
    vextracti128 xmm11, ymm8, 1         ; xmm11 = верхние 128 бит ymm8

    ; --- Запись 16 готовых байт пикселей в память ---
    movq [rsi + r13 + r9], xmm8         ; Первая группа (8 байт) из младшей половины
    movq [rsi + r13 + r9 + 8], xmm11    ; Вторая группа (8 байт) из старшей половины

    add r9, 16                          ; Смещаемся на 16 обработанных пикселей вперед!
    jmp .inner_vector_loop

.inner_scalar_tail:
    ; Хвостовой скалярный обход для пикселей, не укладывающихся в группу из 16 штук
    mov rax, r8
    dec rax                             ; rax = width - 1
    cmp r9, rax
    jge .outer_loop_next

    ; Вычисление Собеля в скалярном режиме
    movzx r10, byte [rdi + r12 + r9 - 1]    ; g00
    mov rax, r10
    neg rax                                  ; gx = -g00
    mov rcx, r10
    neg rcx                                  ; gy = -g00

    movzx r11, byte [rdi + r12 + r9]        ; g01
    shl r11, 1
    sub rcx, r11

    movzx r10, byte [rdi + r12 + r9 + 1]    ; g02
    add rax, r10
    sub rcx, r10

    movzx r11, byte [rdi + r13 + r9 - 1]    ; g10
    shl r11, 1
    sub rax, r11

    movzx r11, byte [rdi + r13 + r9 + 1]    ; g12
    shl r11, 1
    add rax, r11

    movzx r10, byte [rdi + rbx + r9 - 1]    ; g20
    sub rax, r10
    add rcx, r10

    movzx r11, byte [rdi + rbx + r9]        ; g21
    shl r11, 1
    add rcx, r11

    movzx r10, byte [rdi + rbx + r9 + 1]    ; g22
    add rax, r10
    add rcx, r10

    ; Вычисление Abs скалярно
    mov rdx, rax
    sar rdx, 63
    xor rax, rdx
    sub rax, rdx

    mov rdx, rcx
    sar rdx, 63
    xor rcx, rdx
    sub rcx, rdx

    add rax, rcx                         ; Итоговое значение

    cmp rax, 255
    jle .no_clamp_scalar
    mov rax, 255
.no_clamp_scalar:

    mov [rsi + r13 + r9], al
    inc r9
    jmp .inner_scalar_tail

.outer_loop_next:
    inc r14
    jmp .outer_loop

.done:
    vzeroupper                          ; Высокоприоритетный сброс верхних регистров AVX!
    pop r15                             ; Восстановление регистров процессора
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret
