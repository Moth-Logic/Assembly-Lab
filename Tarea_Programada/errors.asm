; ============================================================================
; errors.asm - Mensajes y manejo centralizado de errores
; ----------------------------------------------------------------------------
; QUE HACE:
;   Guarda la tabla de mensajes de error y la subrutina report_error, que
;   imprime el mensaje correspondiente a un codigo y termina el proceso con
;   estado 1. Todos los modulos reportan errores por aqui.
;
; CODIGOS (duplicados como constantes en los modulos que los usan):
;   1 = expresion invalida      2 = division por cero
;   3 = overflow                4 = variable sin asignar
;   5 = mas de 10 variables
;
; EXPORTA (global): report_error
; IMPORTA (extern): io_write  (io.asm)
;
; Convencion System V AMD64: entrada edi = codigo, no retorna.
; ============================================================================
BITS 64
DEFAULT REL

SYS_EXIT equ 60

extern io_write

global report_error

section .data
; Tabla indexada por codigo: 16 bytes por entrada (puntero, longitud).
; La entrada 0 no se usa.
err_msgs:
    dq 0, 0
    dq err_invalid_msg,   err_invalid_len
    dq err_div0_msg,      err_div0_len
    dq err_overflow_msg,  err_overflow_len
    dq err_undef_var_msg, err_undef_var_len
    dq err_toomany_msg,   err_toomany_len

err_invalid_msg:   db "Error: expresion invalida", 10
err_invalid_len    equ $ - err_invalid_msg
err_div0_msg:      db "Error: division por cero", 10
err_div0_len       equ $ - err_div0_msg
err_overflow_msg:  db "Error: overflow", 10
err_overflow_len   equ $ - err_overflow_msg
err_undef_var_msg: db "Error: variable sin asignar", 10
err_undef_var_len  equ $ - err_undef_var_msg
err_toomany_msg:   db "Error: mas de 10 variables", 10
err_toomany_len    equ $ - err_toomany_msg

section .text
; ----------------------------------------------------------------------------
; report_error: imprime el mensaje del codigo edi y sale con estado 1.
;   Un codigo fuera de rango se reporta como "expresion invalida".
; ----------------------------------------------------------------------------
report_error:
    push rbx
    mov ebx, edi
    lea rax, [err_msgs]
    cmp ebx, 1
    jl .force_invalid
    cmp ebx, 5
    jg .force_invalid
    jmp .have_code
.force_invalid:
    mov ebx, 1
.have_code:
    shl rbx, 4                      ; 16 bytes por entrada
    mov rdi, [rax + rbx]
    mov rsi, [rax + rbx + 8]
    call io_write
    mov eax, SYS_EXIT
    mov edi, 1
    syscall                         ; no retorna

section .note.GNU-stack noalloc noexec nowrite progbits
