; ============================================================================
; io.asm - Entrada/salida y conversion numero <-> texto
; ----------------------------------------------------------------------------
; QUE HACE:
;   Encapsula las llamadas al sistema: lectura de stdin (sys_read) y escritura
;   en stdout (sys_write).  Ademas convierte enteros de 128 bits a decimal
;   (io_u128_to_dec) y una cadena de digitos a entero de 128 bits
;   (io_dec_to_u128).  Es el unico modulo que toca los descriptores 0 y 1.
;
; EXPORTA (global): io_read_input, io_write, io_u128_to_dec, io_dec_to_u128,
;                   input_buf, input_len
; IMPORTA (extern): udiv_128, mul_128  (operations.asm)
;
; Convencion System V AMD64:
;   io_read_input             -> rax = bytes leidos
;   io_write     (rdi=ptr, rsi=len)
;   io_u128_to_dec (rdi=destino, rdx:rax=valor) -> rax = longitud
;   io_dec_to_u128 (rdi=ptr, rsi=len)           -> rdx:rax = valor
; ============================================================================
BITS 64
DEFAULT REL

SYS_READ  equ 0
SYS_WRITE equ 1
STDIN     equ 0
STDOUT    equ 1

MAX_INPUT equ 2048

extern udiv_128
extern mul_128

global io_read_input
global io_write
global io_u128_to_dec
global io_dec_to_u128
global input_buf
global input_len

section .bss
input_buf: resb MAX_INPUT
input_len: resq 1

section .text
; ----------------------------------------------------------------------------
; io_read_input: lee hasta MAX_INPUT-1 bytes de stdin, termina con NUL y
;   guarda la longitud en input_len.  Devuelve 0 si no hay entrada.
; ----------------------------------------------------------------------------
io_read_input:
    mov eax, SYS_READ
    xor edi, edi                    ; STDIN
    lea rsi, [input_buf]
    mov edx, MAX_INPUT - 1
    syscall
    test rax, rax
    jle .empty
    mov [input_len], rax
    lea rsi, [input_buf]
    mov byte [rsi + rax], 0
    ret
.empty:
    mov qword [input_len], 0
    xor eax, eax
    ret

; ----------------------------------------------------------------------------
; io_write: escribe rsi bytes desde rdi en stdout.
; ----------------------------------------------------------------------------
io_write:
    mov rdx, rsi
    mov rsi, rdi
    mov edi, STDOUT
    mov eax, SYS_WRITE
    syscall
    ret

; ----------------------------------------------------------------------------
; io_u128_to_dec: rdi = destino, rdx:rax = valor sin signo.
;   Escribe el texto decimal + NUL y devuelve la longitud en rax.
; ----------------------------------------------------------------------------
io_u128_to_dec:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48                     ; area de trabajo (digitos al reves)
    mov r13, rdi                    ; destino
    mov r12, rax                    ; bajo
    mov r14, rdx                    ; alto
    lea r15, [rsp + 48]             ; puntero de escritura (hacia abajo)
    mov rax, r12
    or rax, r14
    jnz .convert
    dec r15
    mov byte [r15], '0'
    jmp .copy
.convert:
    mov rax, r12
    mov rdx, r14
    mov rcx, 10
    xor ebx, ebx
    call udiv_128                   ; cociente r10:r11, resto r8:r9
    mov r12, r10
    mov r14, r11
    mov rax, r8
    add al, '0'
    dec r15
    mov [r15], al
    mov rax, r12
    or rax, r14
    jnz .convert
.copy:
    lea rax, [rsp + 48]
    sub rax, r15                    ; longitud
    mov rbx, rax
    mov rsi, r15
    mov rdi, r13
    mov rcx, rax
    rep movsb
    mov byte [rdi], 0
    mov rax, rbx
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; io_dec_to_u128: rdi = puntero, rsi = longitud -> rdx:rax = valor.
; ----------------------------------------------------------------------------
io_dec_to_u128:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                    ; puntero
    mov r13, rsi                    ; longitud
    xor r14d, r14d                  ; acumulador bajo
    xor r15d, r15d                  ; acumulador alto
    xor ebp, ebp                    ; indice
.loop:
    cmp rbp, r13
    jge .done
    mov rax, r14
    mov rdx, r15
    mov rcx, 10
    xor ebx, ebx
    call mul_128
    movzx r10d, byte [r12 + rbp]
    sub r10d, '0'
    add rax, r10
    adc rdx, 0
    mov r14, rax
    mov r15, rdx
    inc rbp
    jmp .loop
.done:
    mov rax, r14
    mov rdx, r15
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
