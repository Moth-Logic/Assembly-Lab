; ============================================================================
; operations.asm - Implementacion de +, -, *, / y los puntos extra
; ----------------------------------------------------------------------------
; QUE HACE:
;   Aritmetica entera de 128 bits (rax:rdx) y las operaciones de los extras:
;     op_power        base^exp por exponenciacion rapida (enteros)
;     op_power_fixed  idem pero con el factor de escala activo (base escalada)
;     op_modulo       resto con idiv
;     op_exp          e^x por serie de Taylor (40 terminos, punto fijo 1e4)
;   Ninguna rutina usa FPU ni SSE; todo es aritmetica entera.
;
; EXPORTA (global): add_128, sub_128, neg_128, mul_128, div_128, udiv_128,
;                   op_power, op_power_fixed, op_modulo, op_exp
; IMPORTA (extern): report_error  (errors.asm)
;
; Convencion System V AMD64 (valores de 128 bits en rax:bajo / rdx:alto):
;   add_128(rax:rdx, rcx:rbx) -> rax:rdx      sub_128 idem (resta)
;   neg_128(rax:rdx)          -> rax:rdx
;   mul_128(rax:rdx, rcx:rbx) -> rax:rdx
;   div_128(rax:rdx, rcx:rbx) -> rax:rdx      udiv_128 -> r10:r11 cociente,
;                                                          r8:r9 resto
;   op_power(rdi, rsi)        -> rax
;   op_power_fixed(rdi, rsi)  -> rax
;   op_modulo(rdi, rsi)       -> rax
;   op_exp(rdi)               -> rax
; ============================================================================
BITS 64
DEFAULT REL

%ifdef FIXED2
SCALE equ 100                       ; factor de escala de la expresion
%else
SCALE equ 1
%endif

EXP_SCALE  equ 10000                ; escala interna de op_exp (4 decimales)
EXP_LIMIT  equ 200000               ; |x| maximo aceptado por op_exp (+-20.0)

ERR_INVALID  equ 1
ERR_DIV0     equ 2
ERR_OVERFLOW equ 3

extern report_error

global add_128
global sub_128
global neg_128
global mul_128
global div_128
global udiv_128
global op_power
global op_power_fixed
global op_modulo
global op_exp

section .text
; ----------------------------------------------------------------------------
; add_128: rax:rdx += rcx:rbx  (error 3 si hay desbordamiento)
; ----------------------------------------------------------------------------
add_128:
    mov r8, rdx
    mov r9, rbx
    add rax, rcx
    adc rdx, rbx
    mov r10, rdx
    xor r8, r10
    xor r9, r10
    and r8, r9
    js .ov
    ret
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; sub_128: rax:rdx -= rcx:rbx  (error 3 si hay desbordamiento)
; ----------------------------------------------------------------------------
sub_128:
    mov r8, rdx
    mov r9, rbx
    sub rax, rcx
    sbb rdx, rbx
    mov r10, rdx
    mov r11, r8
    xor r11, r10
    xor r8, r9
    and r8, r11
    js .ov
    ret
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; neg_128: rax:rdx = -rax:rdx  (error 3 en el unico caso que desborda)
; ----------------------------------------------------------------------------
neg_128:
    mov r8, 0x8000000000000000
    cmp rdx, r8
    jne .do
    test rax, rax
    jz .ov
.do:
    neg rax
    adc rdx, 0
    neg rdx
    ret
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; mul_128: rax:rdx *= rcx:rbx  (error 3 si el resultado no cabe)
; ----------------------------------------------------------------------------
mul_128:
    push rbp
    push r12
    push r13
    push r14
    push r15
    push rsi
    push rdi
    mov r8, rdx
    xor r8, rbx
    push r8
    mov r9, rdx
    mov r10, rax
    test r9, r9
    jns .a
    neg r10
    adc r9, 0
    neg r9
.a:
    mov r11, rbx
    mov rsi, rcx
    test r11, r11
    jns .b
    neg rsi
    adc r11, 0
    neg r11
.b:
    mov rax, r10
    mul rsi
    mov r12, rax
    mov r13, rdx
    mov rax, r10
    mul r11
    mov r14, rax
    mov r15, rdx
    mov rax, r9
    mul rsi
    mov rdi, rax
    mov rbp, rdx
    mov rax, r9
    mul r11
    mov r10, r13
    xor r9, r9
    add r10, r14
    adc r9, 0
    add r10, rdi
    adc r9, 0
    add rax, r15
    adc rdx, 0
    add rax, rbp
    adc rdx, 0
    add rax, r9
    adc rdx, 0
    test rdx, rdx
    jnz .ov
    test rax, rax
    jnz .ov
    pop r8
    test r8, r8
    js .negative
    test r10, r10
    js .ov
    mov rax, r12
    mov rdx, r10
    jmp .done
.negative:
    test r10, r10
    jns .neg_done
    mov r9, 0x8000000000000000
    cmp r10, r9
    jne .ov
    test r12, r12
    jnz .ov
    mov rax, 0
    mov rdx, r9
    jmp .done
.neg_done:
    mov rax, r12
    mov rdx, r10
    neg rax
    adc rdx, 0
    neg rdx
    jmp .done
.ov:
    mov edi, ERR_OVERFLOW
    call report_error
.done:
    pop rdi
    pop rsi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; ----------------------------------------------------------------------------
; udiv_128: division sin signo de rax:rdx entre rcx:rbx por desplazamientos.
;   -> cociente r10:r11, resto r8:r9
; ----------------------------------------------------------------------------
udiv_128:
    push r12
    mov r10, 0
    mov r11, 0
    mov r8, 0
    mov r9, 0
    mov r12, 128
.loop:
    shl rax, 1
    rcl rdx, 1
    rcl r8, 1
    rcl r9, 1
    shl r10, 1
    rcl r11, 1
    jc .sub
    cmp r9, rbx
    ja .sub
    jb .next
    cmp r8, rcx
    jb .next
.sub:
    sub r8, rcx
    sbb r9, rbx
    or r10, 1
.next:
    dec r12
    jnz .loop
    pop r12
    ret

; ----------------------------------------------------------------------------
; div_128: division con signo de rax:rdx entre rcx:rbx.
;   Error 2 si el divisor es cero, error 3 si el cociente no cabe.
; ----------------------------------------------------------------------------
div_128:
    mov r8, rcx
    or r8, rbx
    jz .dz
    mov r8, 0x8000000000000000
    cmp rdx, r8
    jne .do
    test rax, rax
    jnz .do
    cmp rcx, -1
    jne .do
    cmp rbx, -1
    jne .do
    jmp .ov
.do:
    mov r8, rdx
    xor r8, rbx
    push r8
    push r12
    push r13
    push r14
    push r15
    mov r13, rdx
    mov r12, rax
    test r13, r13
    jns .a
    neg r12
    adc r13, 0
    neg r13
.a:
    mov r15, rbx
    mov r14, rcx
    test r15, r15
    jns .b
    neg r14
    adc r15, 0
    neg r15
.b:
    mov rax, r12
    mov rdx, r13
    mov rcx, r14
    mov rbx, r15
    call udiv_128
    mov rax, r10
    mov rdx, r11
    pop r15
    pop r14
    pop r13
    pop r12
    pop r8
    test r8, r8
    jns .ok
    neg rax
    adc rdx, 0
    neg rdx
.ok:
    ret
.dz:
    mov edi, ERR_DIV0
    call report_error
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; op_power: rdi = base, rsi = exponente -> rax = base^exp
;   Exponenciacion rapida (exponentiation by squaring).
;   exp < 0 -> error 1 (solo enteros).  0^0 = 1.
; ----------------------------------------------------------------------------
op_power:
    test rsi, rsi
    js .bad
    mov rax, 1
    mov r8, rdi                     ; base
    mov rcx, rsi                    ; exponente
.loop:
    test rcx, rcx
    jz .done
    test cl, 1
    jz .no_mul
    imul rax, r8
    jo .ov
.no_mul:
    shr rcx, 1
    jz .done
    imul r8, r8
    jo .ov
    jmp .loop
.done:
    ret
.bad:
    mov edi, ERR_INVALID
    call report_error
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; op_power_fixed: rdi = base escalada xSCALE, rsi = exponente entero.
;   -> rax = base^exp escalado xSCALE (cada producto se reescala).
; ----------------------------------------------------------------------------
op_power_fixed:
    test rsi, rsi
    js .bad
    mov r9, rsi                     ; exponente
    mov r8, rdi                     ; base
    mov rax, SCALE                  ; resultado = 1.0
.loop:
    test r9, r9
    jz .done
    test r9b, 1
    jz .no_mul
    imul rax, r8
    jo .ov
    cqo
    mov rcx, SCALE
    idiv rcx
.no_mul:
    shr r9, 1
    jz .done
    imul r8, r8
    jo .ov
    push rax                        ; la base tambien se reescala, sin
    mov rax, r8                     ; perder el acumulador
    cqo
    mov rcx, SCALE
    idiv rcx
    mov r8, rax
    pop rax
    jmp .loop
.done:
    ret
.bad:
    mov edi, ERR_INVALID
    call report_error
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; op_modulo: rdi = dividendo, rsi = divisor -> rax = resto (idiv).
;   Error 2 si el divisor es cero.
; ----------------------------------------------------------------------------
op_modulo:
    test rsi, rsi
    jz .div0
    mov rax, 0x8000000000000000
    cmp rdi, rax
    jne .do
    cmp rsi, -1
    je .ov                          ; INT64_MIN % -1 desborda idiv
.do:
    mov rax, rdi
    cqo
    idiv rsi                        ; cociente rax, resto rdx
    mov rax, rdx
    ret
.div0:
    mov edi, ERR_DIV0
    call report_error
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; op_exp: rdi = x escalado x10000 -> rax = e^x escalado x10000.
;   Serie de Taylor truncada: sum(x^n/n!) para n = 0..39 (el enunciado pide
;   un minimo de 10 terminos; con 40 la serie es exacta a 4 decimales en todo
;   el rango aceptado, |x| <= 20).
;   Cada termino se calcula como term = term * x / 10000 / n.
;   Para x < 0 se evalua la serie con |x| y se devuelve 1/e^|x|: la serie
;   alterna pierde todos los digitos por cancelacion cuando |x| es grande.
;   |x| > 20 -> error de overflow (la serie perderia sentido).
; ----------------------------------------------------------------------------
op_exp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                    ; x
    xor ebx, ebx                    ; ebx = 1 si x era negativo
    mov rax, r12
    mov rcx, EXP_LIMIT
    cmp rax, rcx
    jg .ov
    mov rcx, -EXP_LIMIT
    cmp rax, rcx
    jl .ov
    test rax, rax
    jns .series
    neg r12                         ; se usa |x|
    mov ebx, 1
.series:
    mov r13, EXP_SCALE              ; termino  = 1.0
    mov r14, EXP_SCALE              ; suma     = 1.0
    mov r15, 1                      ; n = 1
.loop:
    cmp r15, 40
    jge .done
    mov rax, r13
    imul rax, r12
    jo .ov
    cqo
    mov rcx, EXP_SCALE
    idiv rcx
    cqo
    idiv r15
    mov r13, rax
    add r14, rax
    jo .ov
    inc r15
    jmp .loop
.done:
    mov rax, r14
    test ebx, ebx
    jz .ret
    ; x negativo: e^(-|x|) = 1 / e^|x| en punto fijo (con redondeo)
    mov rcx, rax
    mov rax, EXP_SCALE
    imul rax, EXP_SCALE
    mov rdx, rcx
    shr rdx, 1
    add rax, rdx
    cqo
    idiv rcx
.ret:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.ov:
    mov edi, ERR_OVERFLOW
    call report_error

section .note.GNU-stack noalloc noexec nowrite progbits
