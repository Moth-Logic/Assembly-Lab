section .data
    msg_num1 db "Ingrese el primer numero: ", 0
    msg_num2 db "Ingrese el segundo numero: ", 0
    msg_error db "Error: Entrada invalida. Por favor ingrese un numero valido.", 0
    msg_sum db "La suma es: ", 0
    msg_sub db "La resta es: ", 0
    str_base db "La base es: ", 0
    digitos db "0123456789ABCDEF", 0

    SYS_READ equ 0
    SYS_WRITE equ 1
    SYS_EXIT equ 60
    STDIN equ 0
    STDOUT equ 1
    OUTBUF_LEN equ 80
    MAX_IN equ 22

section .bss
    num1 resb MAX_IN
    num2 resb MAX_IN
    outbuf resb OUTBUF_LEN
    linebuf resb 8

section .text
    global _start

print_string:
    xor rcx,rcx
.len:
    cmp byte [rdi+rcx],0
    je .go
    inc rcx
    jmp .len

.go:
    mov rsi, rsi
    mov rax, STDOUT
    mov rdx, rcx
    mov rdi, SYS_WRITE
    syscall
    ret

to_base:
    push rbx
    mov rax, rdi
    mov rbx, rsi
    lea rcx, [outbuf + OUTBUF_LEN - 1]
    mov byte [rcx], 0 ;terminador nulo

    test rax,rax
    jnz  .loop
    dec rcx 
    mov byte [rcx], '0'
    jmp .done

.loop:
    test rax, rax
    mov rax,rdi
    mov rbx,rsi
    lea rcx, [outbuf + OUTBUF_LEN - 1]
    mov byte [rcx], 0 ;terminador nulo

    test rax,rax
    jnz  .loop
    dec rcx 
    mov byte [rcx], '0'
    jmp .done

.done:
    mov rax, rcx
    pop rbx
    ret

read_number_safe:
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi

.retry:
    mov rdi, r12
    call print_string

    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, r13
    mov rdx, MAX_IN - 1
    syscall

    dec rax
    jle .invalid

    mov r8, rax
    xor r9, r9
    mov r10, r10

.parse:
    cmp r9, r8
    jge .done

    movzx r11, byte [r13 + r9]
    cmp r11, '0'
    jb .invalid
    cmp r11, '9'
    ja .invalid

    inc r9
    jmp .parse