section .text
global process_image_asm_scalar

; void process_image_asm_scalar(const unsigned char* src, unsigned char* dst, int width, int height)
; Parameters:
;   rdi = src
;   rsi = dst
;   rdx = width
;   rcx = height

process_image_asm_scalar:
    push rbp
    mov rbp, rsp

    ; Save callee-saved registers
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Store width and height in safe registers
    mov r8, rdx         ; r8 = width
    mov r15, rcx        ; r15 = height

    ; Zero-initialize the entire dst array
    mov rax, r8
    imul rax, r15       ; rax = total pixels
    test rax, rax
    jz .done

    xor r10, r10        ; index = 0
.clear_loop:
    mov byte [rsi + r10], 0
    inc r10
    cmp r10, rax
    jl .clear_loop

    ; Run loop for y from 1 to height - 2
    mov r14, 1          ; r14 = y

.outer_loop:
    mov rax, r15
    dec rax             ; rax = height - 1
    cmp r14, rax        ; compare y with height - 1
    jge .done

    ; Calculate row offsets
    ; r13 = y * width
    mov r13, r14
    imul r13, r8

    ; r12 = (y - 1) * width
    mov r12, r13
    sub r12, r8

    ; rbx = (y + 1) * width
    mov rbx, r13
    add rbx, r8

    ; Convert row offsets into absolute memory pointers by adding src base (rdi)
    add r12, rdi        ; r12 = src + (y - 1) * width
    add r13, rdi        ; r13 = src + y * width
    add rbx, rdi        ; rbx = src + (y + 1) * width

    ; Compute dst absolute row pointer in r11 (rsi + y * width)
    mov r11, r14
    imul r11, r8
    add r11, rsi        ; r11 = dst + y * width

    ; Inner loop for x from 1 to width - 2
    mov r9, 1           ; r9 = x

.inner_loop:
    mov rax, r8
    dec rax             ; rax = width - 1
    cmp r9, rax         ; compare x with width - 1
    jge .outer_loop_next

    ; Fetch row-0 elements
    movzx r10, byte [r12 + r9 - 1]    ; g00
    
    ; gx = -g00
    mov rax, r10
    neg rax

    ; gy = -g00
    mov rcx, r10
    neg rcx

    ; Fetch g01 (use r10 as standard temporary)
    movzx r10, byte [r12 + r9]        ; g01
    ; gy -= 2 * g01
    shl r10, 1
    sub rcx, r10

    ; Fetch g02
    movzx r10, byte [r12 + r9 + 1]    ; g02
    ; gx += g02
    add rax, r10
    ; gy -= g02
    sub rcx, r10

    ; Fetch Row-1 elements
    ; Fetch g10
    movzx r10, byte [r13 + r9 - 1]    ; g10
    ; gx -= 2 * g10
    shl r10, 1
    sub rax, r10

    ; Fetch g12
    movzx r10, byte [r13 + r9 + 1]    ; g12
    ; gx += 2 * g12
    shl r10, 1
    add rax, r10

    ; Fetch Row-2 elements
    ; Fetch g20
    movzx r10, byte [rbx + r9 - 1]    ; g20
    ; gx -= g20
    sub rax, r10
    ; gy += g20
    add rcx, r10

    ; Fetch g21
    movzx r10, byte [rbx + r9]        ; g21
    ; gy += 2 * g21
    shl r10, 1
    add rcx, r10

    ; Fetch g22
    movzx r10, byte [rbx + r9 + 1]    ; g22
    ; gx += g22
    add rax, r10
    ; gy += g22
    add rcx, r10

    ; Compute abs(gx) branchlessly
    mov rdx, rax
    sar rdx, 63
    xor rax, rdx
    sub rax, rdx

    ; Compute abs(gy) branchlessly
    mov rdx, rcx
    sar rdx, 63
    xor rcx, rdx
    sub rcx, rdx

    ; Add magnitude mag = abs(gx) + abs(gy)
    add rax, rcx

    ; Clamp to 255
    cmp rax, 255
    jle .no_clamp
    mov rax, 255
.no_clamp:

    ; Store result in dst[y * width + x]
    ; r11 is pristine and untouched because we only used r10 as the temp register!
    mov [r11 + r9], al

    ; Loop increment x
    inc r9
    jmp .inner_loop

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
