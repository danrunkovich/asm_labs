section .text
global process_image_asm_scalar

; void process_image_asm_scalar (const unsigned char* grey_src,
;   unsigned char* grey_dst, const int width, const int height);
;
;   rdi = src
;   rsi = dst
;   rdx = width
;   rcx = height


process_image_asm_scalar:

    push rbp
    mov rbp, rsp

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r8, rdx ; r8 = width
    mov r15, rcx ; r15 = height

    mov rax, r8
    imul rax, r15
    test rax, rax
    jz .done

    xor r10, r10
    .clear_loop:
        mov byte [rsi + r10], 0
        inc r10
        cmp r10, rax
        jl .clear_loop

    mov r14, 1 ; r14 = y ( 1 <= y <= height - 1 )
    .y_loop:
        mov rax, r15
        dec rax
        cmp r14, rax
        jge .done

        mov r13, r14 ; r13 = y
        imul r13, r8 ; r13 = y * width

        mov r12, r13
        sub r12, r8 ; r12 = (y - 1) * width
        mov rbx, r13
        add rbx, r8 ; rbx = (y + 1) * width

        mov r9, 1 ; r9 = x ( 1 <= x <= width - 1 )

        .x_loop:
            mov rax, r8
            dec rax
            cmp r9, rax
            jge .x_loop_done

            movzx r10, byte [rdi + r12 + r9 - 1] ; r10 = g00
            mov rax, r10
            neg rax ; gx = rax = -rax = -g00
            mov rcx, r10
            neg rcx ; gy = rcx = -rcx = -g00

            movzx r11, byte [rdi + r12 + r9] ; r11 = g01
            shl r11, 1 ; r11 = g01
            sub rcx, r11 ; rcx -= 2*g01

            movzx r10, byte [rdi + r12 + r9 + 1] ; r10 = g02
            add rax, r10 ; gx = rax += g02
            sub rcx, r10 ; gy = rcx -= g02

            movzx r11, byte [rdi + r13 + r9 - 1] ; r11 = g10
            shl r11, 1
            sub rax, r11 ; gx = rax -= 2*g10

            movzx r11, byte [rdi + r13 + r9 + 1] ; r11 = g12
            shl r11, 1
            add rax, r11 ; gx = rax += g12

            movzx r11, byte [rdi + rbx + r9 - 1] ; r11 = g20
            sub rax, r11 ; gx = rax -= g20
            add rcx, r11 ; gy = rcx += g20

            movzx r11, byte [rdi + rbx + r9] ; r11 = g21
            shl r11, 1
            add rcx, r11 ; gy = rcx += 2 * g21

            movzx r11, byte [rdi + rbx + r9 + 1] ; r11 = g22
            add rax, r11 ; gx = rax += g22
            add rcx, r11 ; gy = rcx += g22

            mov rdx, rax
            sar rdx, 63
            xor rax, rdx
            sub rax, rdx

            mov rdx, rcx
            sar rdx, 63
            xor rcx, rdx
            sub rcx, rdx

            add rax, rcx
            cmp rax, 255
            jle .no_clamping
            mov rax, 255
            .no_clamping:

            mov [rsi + r13 + r9], al

            inc r9
            jmp .x_loop

            .x_loop_done:
            inc r14
            jmp .y_loop

    .done:
        pop r15
        pop r14
        pop r13
        pop r12
        pop rbx
        leave
        ret
