;res = (a**3 + b**3) / (a**2 * c - b**2 * d + e)

section .data
    a dq 0x100000
    b dd 0x100000
    c dd 0
    d dw 0
    e db 1
    res dq 0
    rmndr dq 0

section .text
global _start

_start:
    ;a**3
   mov rax, [a]
  imul rax, [a]
    jo error
   imul rax, [a]
    jo error
      mov r8, rax

   ;b**3
   movsxd rax, dword[b]
   mov r9, rax
   imul r9, rax
 
   imul r9, rax
   jo error
 
   ;a**3 + b**3
   add r8, r9
   jo error
 

   ;a**2 * c
   mov rax, [a]
   imul rax, [a]
   jo error
 
   movsxd r9, dword[c]
   imul r9, rax
   jo error
 
   ;b**2 * d
   movsxd rax, dword[b]
   mov r10, rax
   imul r10, rax
   movsx rax, word[d]
   imul r10, rax
   jo error
 
   ;a**2 * c - b**2 * d
   sub r9, r10
   jo error

   ;a**2 * c - b**2 * d + e
   movsx rax, byte[e]
   add r9, rax
   jo error

   ;divisor is correct?
   cmp r9, 0
   je error

   ;res, rmndr
   mov rax, r8
   cqo
   idiv r9
   mov [res], rax
   mov [rmndr], rdx

end:
   mov rax, 60
   xor rdi, rdi
   syscall

error:
    mov rax, 60
    mov rdi, 1
    syscall
