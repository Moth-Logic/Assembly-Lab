; ============================================================================
; variables.asm - Tabla de variables: busqueda e insercion
; ----------------------------------------------------------------------------
; QUE HACE:
;   Mantiene la tabla de hasta 10 variables. Los nombres son una sola letra
;   (a-z, A-Z); los valores son enteros de 128 bits guardados como pares
;   (bajo, alto) y, si el factor de escala esta activo, ya escalados x100.
;   lookup_var busca el valor de una variable (error si no esta definida)
;   y store_var actualiza o inserta (error si ya hay 10 variables).
;
; EXPORTA (global): lookup_var, store_var, var_count
; IMPORTA (extern): report_error  (errors.asm)
;
; Convencion System V AMD64:
;   lookup_var: dil = nombre            -> rax:rdx = valor
;   store_var : dil = nombre, rax:rdx = valor
; ============================================================================
BITS 64
DEFAULT REL

MAX_VARS      equ 10
ERR_UNDEF_VAR equ 4
ERR_TOOMANY   equ 5

extern report_error

global lookup_var
global store_var
global var_count

section .bss
var_names:   resb MAX_VARS * 8      ; nombre (1 byte) por variable
var_defined: resb MAX_VARS          ; 1 = definida
var_vals:    resq MAX_VARS * 2      ; valor 128 bits (bajo, alto)
var_count:   resq 1

section .text
; ----------------------------------------------------------------------------
; lookup_var: dil = nombre -> rax:rdx = valor.  Error 4 si no existe.
; ----------------------------------------------------------------------------
lookup_var:
    push rbx
    push rcx
    push rsi
    xor ecx, ecx
.search:
    cmp rcx, [var_count]
    jge .not_found
    lea rsi, [var_names]
    mov rbx, rcx
    shl rbx, 3
    cmp byte [rsi + rbx], dil
    je .found
    inc rcx
    jmp .search
.found:
    lea rsi, [var_defined]
    cmp byte [rsi + rcx], 0
    je .not_found
    lea rsi, [var_vals]
    mov rbx, rcx
    shl rbx, 4
    mov rax, [rsi + rbx]
    mov rdx, [rsi + rbx + 8]
    pop rsi
    pop rcx
    pop rbx
    ret
.not_found:
    mov edi, ERR_UNDEF_VAR
    call report_error

; ----------------------------------------------------------------------------
; store_var: dil = nombre, rax:rdx = valor.  Error 5 si la tabla esta llena.
; ----------------------------------------------------------------------------
store_var:
    push rbx
    push rcx
    push rsi
    xor ecx, ecx
.search:
    cmp rcx, [var_count]
    jge .append
    lea rsi, [var_names]
    mov rbx, rcx
    shl rbx, 3
    cmp byte [rsi + rbx], dil
    je .update
    inc rcx
    jmp .search
.update:
    lea rsi, [var_vals]
    mov rbx, rcx
    shl rbx, 4
    mov [rsi + rbx], rax
    mov [rsi + rbx + 8], rdx
    lea rsi, [var_defined]
    mov byte [rsi + rcx], 1
    jmp .done
.append:
    cmp qword [var_count], MAX_VARS
    jge .too_many
    lea rsi, [var_names]
    mov rbx, [var_count]
    shl rbx, 3
    mov byte [rsi + rbx], dil
    lea rsi, [var_vals]
    mov rbx, [var_count]
    shl rbx, 4
    mov [rsi + rbx], rax
    mov [rsi + rbx + 8], rdx
    lea rsi, [var_defined]
    mov rcx, [var_count]
    mov byte [rsi + rcx], 1
    inc qword [var_count]
    jmp .done
.too_many:
    mov edi, ERR_TOOMANY
    call report_error
.done:
    pop rsi
    pop rcx
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
