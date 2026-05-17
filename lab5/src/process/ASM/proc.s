section .text
global process_image_asm

; void process_image_asm(unsigned char* data, int width, int height, int channels, int use_max)
; rdi = data (указатель на массив пикселей)
; rsi = width (ширина)
; rdx = height (высота)
; rcx = channels (количество каналов, например 3 для RGB)
; r8 = use_max (флаг: 1 для Max, 0 для Min)

process_image_asm:
    push rbp
    mov rbp, rsp


    push r12
    sub rsp, 8


    cmp rcx, 3
    jl .done


    mov rax, rsi ; rax = width
    imul rax, rdx ; rax = pixel_count
    mov r9, rax ; r9 = pixel_count

    test r9, r9 ; если 0 пикселей, выходим
    jz .done

.loop:
    movzx r10, byte [rdi] ; r
    movzx r11, byte [rdi + 1] ; g
    movzx r12, byte [rdi + 2] ; b

    test r8, r8 ; флаг use_max
    jz .min_logic

.max_logic:
    mov rax, r10 ; Начинаем с R
    cmp r11, rax
    cmovg rax, r11 ; Если G > текущего Max, берем G
    cmp r12, rax
    cmovg rax, r12 ; Если B > текущего Max, берем B
    jmp .store

.min_logic:
    mov rax, r10 ; Начинаем с R
    cmp r11, rax
    cmovl rax, r11 ; Если G < текущего Min, берем G
    cmp r12, rax
    cmovl rax, r12 ; Если B < текущего Min, берем B

.store:
    ; Записываем полученное значение серого во все три канала (R, G, B)
    mov [rdi], al
    mov [rdi + 1], al
    mov [rdi + 2], al

    ; Переходим к следующему пикселю, прибавляя количество каналов к указателю
    add rdi, rcx
    dec r9
    jnz .loop

.done:
    add rsp, 8
    pop r12
    leave
    ret
