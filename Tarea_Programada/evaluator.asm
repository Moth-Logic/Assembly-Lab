; ============================================================================
; evaluator.asm - Evaluacion de la expresion (pila de operandos/operadores)
; ----------------------------------------------------------------------------
; QUE HACE:
;   Guarda la lista de tokens que produce parser.asm y la reduce operacion a
;   operacion hasta dejar un unico operando, que es el resultado.  En cada
;   vuelta elige la operacion de mayor prioridad del grupo de parentesis mas
;   interno (pila de operadores) y aplica los dos operandos a traves de una
;   pila de valores de 128 bits:
;       prioridad 4: **            (asociativa por la derecha)
;       prioridad 3: menos unario
;       prioridad 2: * / %
;       prioridad 1: + -
;   Tambien elimina parentesis triviales, aplica e(...) y avisa a display.asm
;   para que guarde cada estado intermedio (Extra 4).
;
; EXPORTA (global): eval_expression, tok_add, tok_reset, tok_count, tokens
; IMPORTA (extern): display_reset_steps, display_record_step (display.asm)
;                   add_128, sub_128, neg_128, mul_128, div_128,
;                   op_power, op_power_fixed, op_modulo, op_exp
;                                                          (operations.asm)
;                   report_error                            (errors.asm)
;
; Convencion System V AMD64: eval_expression -> rax:rdx (resultado 128 bits)
; ============================================================================
BITS 64
DEFAULT REL

%ifdef FIXED2
SCALE equ 100
%else
SCALE equ 1
%endif

ERR_INVALID  equ 1
ERR_OVERFLOW equ 3

; Tipos de token compartidos con parser.asm y display.asm
T_NUM equ 1
T_OP  equ 2
T_LP  equ 3
T_RP  equ 4
T_NEG equ 5
T_EXP equ 6

EXP_SCALE    equ 10000              ; escala interna de op_exp (4 decimales)
TOKSZ    equ 32                     ; bytes por token
MAX_TOKS equ 4096                   ; tokens maximos
OP_STACK_SIZE equ 64

extern display_reset_steps
extern display_record_step
extern add_128
extern sub_128
extern neg_128
extern mul_128
extern div_128
extern op_power
extern op_power_fixed
extern op_modulo
extern op_exp
extern report_error

global eval_expression
global tok_add
global tok_reset
global tok_count
global tokens

section .bss
; Cada token: +0 tipo, +8 valor bajo, +16 valor alto, +24 relleno
tokens:     resb MAX_TOKS * TOKSZ
tok_count:  resq 1
val_stack:  resq 64 * 2             ; pila de operandos (bajo, alto)
val_sp:     resq 1
op_stack:   resb OP_STACK_SIZE      ; pila de operadores
op_sp:      resq 1

section .text
; ----------------------------------------------------------------------------
; tok_reset: vacia la lista de tokens.
; ----------------------------------------------------------------------------
tok_reset:
    mov qword [tok_count], 0
    ret

; ----------------------------------------------------------------------------
; tok_add: agrega un token.   edi = tipo, rax:rdx = valor
; ----------------------------------------------------------------------------
tok_add:
    push rbx
    push rcx
    push r8
    mov rbx, [tok_count]
    cmp rbx, MAX_TOKS
    jae .full
    mov rcx, rbx
    shl rcx, 5
    lea r8, [tokens]
    mov [r8 + rcx], rdi
    mov [r8 + rcx + 8], rax
    mov [r8 + rcx + 16], rdx
    inc qword [tok_count]
    pop r8
    pop rcx
    pop rbx
    ret
.full:
    mov edi, ERR_INVALID
    call report_error

; ----------------------------------------------------------------------------
; tok_remove_range: elimina rsi tokens a partir del indice rdi, desplazando
;   el resto hacia atras.
; ----------------------------------------------------------------------------
tok_remove_range:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                    ; inicio
    mov r13, rsi                    ; cuantos
    mov r14, [tok_count]
    mov r15, r12
    add r15, r13                    ; primer token que se conserva
    cmp r15, r14
    jge .shrink
    mov rcx, r14
    sub rcx, r15
    shl rcx, 5                      ; bytes a mover
    mov rax, r15
    shl rax, 5
    lea rsi, [tokens]
    add rsi, rax
    mov rax, r12
    shl rax, 5
    lea rdi, [tokens]
    add rdi, rax
    rep movsb
.shrink:
    sub [tok_count], r13
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; Pila de operandos (128 bits) y de operadores
; ----------------------------------------------------------------------------
eval_push_val:                      ; rax:rdx
    mov rcx, [val_sp]
    lea r8, [val_stack]
    shl rcx, 4
    mov [r8 + rcx], rax
    mov [r8 + rcx + 8], rdx
    inc qword [val_sp]
    ret

eval_pop_val:                       ; -> rax:rdx
    dec qword [val_sp]
    mov rcx, [val_sp]
    lea r8, [val_stack]
    shl rcx, 4
    mov rax, [r8 + rcx]
    mov rdx, [r8 + rcx + 8]
    ret

eval_push_op:                       ; dil = operador
    mov rcx, [op_sp]
    lea r8, [op_stack]
    mov [r8 + rcx], dil
    inc qword [op_sp]
    ret

eval_pop_op:                        ; -> eax = operador
    dec qword [op_sp]
    mov rcx, [op_sp]
    lea r8, [op_stack]
    movzx eax, byte [r8 + rcx]
    ret

; ----------------------------------------------------------------------------
; eval_expression: reduce tokens hasta un resultado.
;   -> rax:rdx = valor final.  Guarda los estados intermedios en display.
; ----------------------------------------------------------------------------
eval_expression:
    push rbx
    push r12
    call display_reset_steps
    mov qword [val_sp], 0
    mov qword [op_sp], 0
    cmp qword [tok_count], 0
    je .invalid
    cmp qword [tok_count], 1
    jle .loop
    call eval_record_state
.loop:
    cmp qword [tok_count], 1
    jle .finish
    call eval_step
    cmp qword [tok_count], 1
    jle .loop                       ; el estado final no se repite
    call eval_record_state
    jmp .loop
.finish:
    lea rbx, [tokens]
    mov rax, [rbx + 8]
    mov rdx, [rbx + 16]
    pop r12
    pop rbx
    ret
.invalid:
    mov edi, ERR_INVALID
    call report_error

; ----------------------------------------------------------------------------
; eval_record_state: pide a display.asm que guarde el estado actual, salvo que
;   ya sea solo un operando (NUM con signos unarios): ese caso es el resultado
;   final y main.asm lo imprime, asi que no se repite como paso.
; ----------------------------------------------------------------------------
eval_record_state:
    push rbx
    lea rbx, [tokens]
    xor ecx, ecx
.scan:
    cmp rcx, [tok_count]
    jge .done
    mov rax, rcx
    shl rax, 5
    mov rdx, [rbx + rax]
    cmp rdx, T_NUM
    je .next
    cmp rdx, T_NEG
    je .next
    call display_record_step
    jmp .done
.next:
    inc rcx
    jmp .scan
.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; eval_step: realiza una sola simplificacion.
;   1) aplica e(...) si ya se puede
;   2) reduce la operacion de mayor prioridad del grupo mas interno
;   3) quita los parentesis que quedaron alrededor de un unico numero
; ----------------------------------------------------------------------------
eval_step:
    push rbx
    call eval_apply_exp
    test eax, eax
    jnz .after
    call eval_find_candidate
    cmp rax, -1
    je .try_strip
    mov rdi, rax
    mov rcx, rax
    shl rcx, 5
    lea rdx, [tokens]
    mov rsi, [rdx + rcx]
    cmp rsi, T_NEG
    je .unary
    call eval_binary
    jmp .after
.unary:
    call eval_unary
    jmp .after
.try_strip:
    call eval_strip_parens
    test eax, eax
    jz .invalid
    jmp .done
.after:
    call eval_strip_parens
    test eax, eax
    jnz .after
.done:
    pop rbx
    ret
.invalid:
    mov edi, ERR_INVALID
    call report_error

; ----------------------------------------------------------------------------
; eval_strip_parens: elimina un grupo "( NUM )".  -> eax = 1 si actuo
; ----------------------------------------------------------------------------
eval_strip_parens:
    push rbx
    push r12
    push r13
    lea r12, [tokens]
    xor r13d, r13d
.scan:
    mov rax, [tok_count]
    sub rax, 2
    cmp r13, rax
    jge .none
    mov rbx, r13
    shl rbx, 5
    mov rax, [r12 + rbx]
    cmp rax, T_LP
    jne .next
    ; los parentesis de e(...) los consume eval_apply_exp
    test r13, r13
    jz .no_exp
    mov rax, r13
    shl rax, 5
    mov rax, [r12 + rax - 32]
    cmp rax, T_EXP
    je .next
.no_exp:
    mov rax, [r12 + rbx + 32]
    cmp rax, T_NUM
    jne .next
    mov rax, [r12 + rbx + 64]
    cmp rax, T_RP
    jne .next
    ; copia el NUM al lugar del '(' y elimina '(' NUM
    mov rax, [r12 + rbx + 32]
    mov [r12 + rbx], rax
    mov rax, [r12 + rbx + 40]
    mov [r12 + rbx + 8], rax
    mov rax, [r12 + rbx + 48]
    mov [r12 + rbx + 16], rax
    lea rdi, [r13 + 1]
    mov esi, 2
    call tok_remove_range
    mov eax, 1
    jmp .done
.next:
    inc r13
    jmp .scan
.none:
    xor eax, eax
.done:
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; eval_apply_exp: aplica op_exp al primer "e ( NUM )" listo.
;   -> eax = 1 si actuo
; ----------------------------------------------------------------------------
eval_apply_exp:
    push rbx
    push r12
    push r13
    push r14
    push r15
    lea r14, [tokens]
    xor r13d, r13d
.scan:
    mov rax, [tok_count]
    sub rax, 1
    cmp r13, rax
    jge .none
    mov rbx, r13
    shl rbx, 5
    mov rax, [r14 + rbx]
    cmp rax, T_EXP
    jne .next
    ; --- formas aceptadas: e NUM  y  e ( NUM ) ---
    mov rax, [r14 + rbx + 32]
    cmp rax, T_NUM
    je .direct
    cmp rax, T_LP
    jne .next
    mov rax, r13
    add rax, 3
    cmp rax, [tok_count]
    jge .next
    mov rax, [r14 + rbx + 64]
    cmp rax, T_NUM
    jne .next
    mov rax, [r14 + rbx + 96]
    cmp rax, T_RP
    jne .next
    mov rax, [r14 + rbx + 72]
    mov rdx, [r14 + rbx + 80]
    mov r15, 3                      ; e ( NUM )
    jmp .compute
.direct:
    mov rax, [r14 + rbx + 40]
    mov rdx, [r14 + rbx + 48]
    mov r15, 1                      ; e NUM
.compute:
    ; --- valor del argumento, debe caber en 64 bits ---
    mov rcx, rax
    sar rcx, 63
    cmp rcx, rdx
    jne .overflow
    ; --- x en escala 10000 ---
    mov rdi, rax
%ifdef FIXED2
    imul rdi, EXP_SCALE / SCALE
%else
    imul rdi, EXP_SCALE
%endif
    jo .overflow
    call op_exp                     ; rax = e^x escalado x10000
    ; --- de vuelta a la escala de la expresion, redondeando ---
    mov rcx, EXP_SCALE / SCALE
    mov r8, rcx
    shr r8, 1
    test rax, rax
    js .round_down
    add rax, r8
    jmp .divide
.round_down:
    sub rax, r8
.divide:
    cqo
    idiv rcx
    mov rdx, rax
    sar rdx, 63
    ; --- sustituye "e NUM" por el resultado ---
    mov [r14 + rbx], qword T_NUM
    mov [r14 + rbx + 8], rax
    mov [r14 + rbx + 16], rdx
    lea rdi, [r13 + 1]
    mov rsi, r15
    call tok_remove_range
    mov eax, 1
    jmp .done
.next:
    inc r13
    jmp .scan
.none:
    xor eax, eax
    jmp .done
.overflow:
    mov edi, ERR_OVERFLOW
    call report_error
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; eval_find_candidate: elige la operacion a reducir.
;   Solo mira el grupo de parentesis mas interno y, dentro de el, la de mayor
;   prioridad; en caso de empate toma la de mas a la izquierda salvo **, que
;   se asocia por la derecha.
;   -> rax = indice del token, o -1 si no hay ninguno
; ----------------------------------------------------------------------------
eval_find_candidate:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    lea r15, [tokens]

    ; ---- pasada 1: profundidad maxima que contiene operadores ----
    xor r8d, r8d                    ; profundidad
    xor r9d, r9d                    ; maxima
    xor r10d, r10d                  ; indice
.pass1:
    cmp r10, [tok_count]
    jge .pass1_done
    mov rax, r10
    shl rax, 5
    mov rcx, [r15 + rax]
    cmp rcx, T_LP
    je .p1_open
    cmp rcx, T_RP
    je .p1_close
    cmp rcx, T_OP
    je .p1_op
    cmp rcx, T_NEG
    jne .p1_next
.p1_op:
    cmp r8, r9
    jle .p1_next
    mov r9, r8
    jmp .p1_next
.p1_open:
    inc r8
    jmp .p1_next
.p1_close:
    dec r8
.p1_next:
    inc r10
    jmp .pass1
.pass1_done:
    mov r12, r9                     ; profundidad objetivo

    ; ---- pasada 2: mejor candidato ----
    xor r8d, r8d                    ; profundidad
    xor r10d, r10d                  ; indice
    mov r13, -1                     ; mejor indice
    xor r14d, r14d                  ; mejor prioridad
.pass2:
    cmp r10, [tok_count]
    jge .pass2_done
    mov rax, r10
    shl rax, 5
    mov rcx, [r15 + rax]
    cmp rcx, T_LP
    je .p2_open
    cmp rcx, T_RP
    je .p2_close
    cmp rcx, T_OP
    je .p2_check
    cmp rcx, T_NEG
    jne .p2_next
.p2_check:
    cmp r8, r12
    jne .p2_next                    ; solo el grupo mas interno
    mov rax, r10
    inc rax
    cmp rax, [tok_count]
    jge .p2_next                    ; sin operando a la derecha
    mov rax, r10
    shl rax, 5
    mov rdx, [r15 + rax + 32]       ; tipo de i+1
    cmp rdx, T_NUM
    jne .p2_next
    cmp rcx, T_NEG
    je .eligible                    ; el unario no necesita nada a la izquierda
    test r10, r10
    jz .p2_next                     ; sin operando a la izquierda
    mov rdx, [r15 + rax - 32]       ; tipo de i-1
    cmp rdx, T_NUM
    jne .p2_next
.eligible:
    ; ---- prioridad ----
    mov r11, [r15 + rax + 8]        ; caracter del operador
    cmp rcx, T_NEG
    je .pri_neg
    cmp r11b, '^'
    je .pri_pow
    cmp r11b, '*'
    je .pri_mul
    cmp r11b, '/'
    je .pri_mul
    cmp r11b, '%'
    je .pri_mul
    jmp .pri_add
.pri_pow:
    mov ebx, 4
    jmp .pri_have
.pri_neg:
    mov ebx, 3
    jmp .pri_have
.pri_mul:
    mov ebx, 2
    jmp .pri_have
.pri_add:
    mov ebx, 1
.pri_have:
    cmp rbx, r14
    jg .take
    jl .p2_next
    cmp r11b, '^'                   ; empate: ** toma el de la derecha
    jne .p2_next
.take:
    mov r13, r10
    mov r14, rbx
.p2_next:
    inc r10
    jmp .pass2
.p2_open:
    inc r8
    jmp .p2_next
.p2_close:
    dec r8
    jmp .p2_next
.pass2_done:
    mov rax, r13
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; ----------------------------------------------------------------------------
; eval_unary: aplica el menos unario del token i (rdi).
; ----------------------------------------------------------------------------
eval_unary:
    push r12
    mov r12, rdi
    mov r9, r12
    shl r9, 5
    lea r8, [tokens]
    mov rax, [r8 + r9 + 40]
    mov rdx, [r8 + r9 + 48]
    call neg_128
    mov r9, r12
    shl r9, 5
    lea r8, [tokens]
    mov [r8 + r9], qword T_NUM
    mov [r8 + r9 + 8], rax
    mov [r8 + r9 + 16], rdx
    lea rdi, [r12 + 1]
    mov esi, 1
    call tok_remove_range
    pop r12
    ret

; ----------------------------------------------------------------------------
; eval_binary: aplica la operacion del token i (rdi) usando la pila de
;   operandos y la pila de operadores.
; ----------------------------------------------------------------------------
eval_binary:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, r12
    shl r13, 5
    lea r14, [tokens]

    ; ---- operandos a la pila ----
    mov rax, [r14 + r13 - 24]       ; izquierda (i-1)
    mov rdx, [r14 + r13 - 16]
    call eval_push_val
    mov rax, [r14 + r13 + 40]       ; derecha (i+1)
    mov rdx, [r14 + r13 + 48]
    call eval_push_val
    mov rdi, [r14 + r13 + 8]        ; operador
    call eval_push_op

    ; ---- operador y operandos desde la pila ----
    call eval_pop_op
    mov r15d, eax
    call eval_pop_val
    mov r10, rax                    ; derecha, en r10:r11 porque la pila
    mov r11, rdx                    ; usa rcx al desapilar el otro operando
    call eval_pop_val               ; izquierda en rax:rdx
    mov rcx, r10                    ; derecha en rcx:rbx
    mov rbx, r11

    cmp r15b, '+'
    je .add
    cmp r15b, '-'
    je .sub
    cmp r15b, '*'
    je .mul
    cmp r15b, '/'
    je .div
    cmp r15b, '%'
    je .mod
    jmp .pow

.add:
    call add_128
    jmp .store
.sub:
    call sub_128
    jmp .store
.mul:
    call mul_128
%ifdef FIXED2
    mov rcx, SCALE
    xor ebx, ebx
    call div_128
%endif
    jmp .store
.div:
%ifdef FIXED2
    push rbx
    push rcx
    mov rcx, SCALE
    xor ebx, ebx
    call mul_128
    pop rcx
    pop rbx
%endif
    call div_128
    jmp .store
.mod:
    call check_64
    mov rdi, rax
    mov rsi, rcx
    call op_modulo
    cqo
    jmp .store
.pow:
    call check_64
    mov r10, rax                    ; base
    mov r11, rcx                    ; exponente (escalado)
    test r11, r11
    js .bad_exp
%ifdef FIXED2
    mov rax, r11
    cqo
    mov rcx, SCALE
    idiv rcx
    test rdx, rdx
    jnz .bad_exp                    ; exponente fraccionario
    mov r11, rax
%endif
    mov rdi, r10
    mov rsi, r11
%ifdef FIXED2
    call op_power_fixed
%else
    call op_power
%endif
    cqo
    jmp .store

.store:
    ; el resultado sustituye al operando izquierdo (i-1); se eliminan el
    ; operador y el operando derecho
    mov r13, r12
    dec r13
    shl r13, 5
    lea r14, [tokens]
    mov [r14 + r13], qword T_NUM
    mov [r14 + r13 + 8], rax
    mov [r14 + r13 + 16], rdx
    mov rdi, r12
    mov esi, 2
    call tok_remove_range
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.bad_exp:
    mov edi, ERR_INVALID
    call report_error
.overflow:
    mov edi, ERR_OVERFLOW
    call report_error

; ----------------------------------------------------------------------------
; check_64: exige que rax:rdx y rcx:rbx quepan en 64 bits (extension de signo);
;   si no, reporta overflow.  Se usa antes de op_modulo y de las potencias.
; ----------------------------------------------------------------------------
check_64:
    mov r8, rax
    sar r8, 63
    cmp r8, rdx
    jne .overflow
    mov r8, rcx
    sar r8, 63
    cmp r8, rbx
    jne .overflow
    ret
.overflow:
    mov edi, ERR_OVERFLOW
    call report_error

section .note.GNU-stack noalloc noexec nowrite progbits
