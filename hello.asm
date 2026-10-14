
global _start

section .data
    msg db "Hello, x86-64!", 10
    len equ $ - msg

section .text
_start:
    mov rax, 1          ; syscall: write
    mov rdi, 1          ; stdout
    mov rsi, msg        ; mensaje
    mov rdx, len        ; longitud
    syscall

    mov rax, 60         ; syscall: exit
    xor rdi, rdi        ; codigo de salida 0
    syscall
