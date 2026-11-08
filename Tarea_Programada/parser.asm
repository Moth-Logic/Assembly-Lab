; ============================================================================
; parser.asm - Tokenizer, sustitucion de variables y validacion sintactica
; ----------------------------------------------------------------------------
; QUE HACE:
;   Recorre la entrada y la convierte en una lista de tokens que el evaluador
;   reduce paso a paso.  Se encarga de:
;     - localizar donde termina la expresion (coma de nivel 0),
;     - leer las asignaciones "x=50, y=-3" y guardarlas en la tabla de
;       variables (sustitucion de variables),
;     - tokenizar numeros (aplicando el factor de escala), variables ya
;       sustituidas por su valor, parentesis, operadores + - * / % **,
;       el menos unario y la funcion e(...),
;     - insertar la multiplicacion implicita (2x, 2(3+4), (1)(2)),
;     - validar la sintaxis y reportar el error 1 si algo no cuadra.
;
; EXPORTA (global): parser_find_expr_end, parser_parse_assignments,
;                   parser_begin_expression, parser_tokenize
; IMPORTA (extern): input_buf, input_len, io_dec_to_u128  (io.asm)
;                   mul_128                              (operations.asm)
;                   lookup_var, store_var                (variables.asm)
;                   tok_add, tok_reset, tok_count, tokens (evaluator.asm)
;                   report_error                         (errors.asm)
; ============================================================================
BITS 64
DEFAULT REL

%ifdef FIXED2
SCALE equ 100
%else
SCALE equ 1
%endif

ERR_INVALID equ 1

; Tipos de token compartidos con evaluator.asm y display.asm
T_NUM equ 1
T_OP  equ 2
T_LP  equ 3
T_RP  equ 4
T_NEG equ 5
T_EXP equ 6

extern input_buf
extern input_len
extern io_dec_to_u128
extern mul_128
extern lookup_var
extern store_var
extern tok_add
extern tok_reset
extern tok_count
extern tokens
extern report_error

global parser_find_expr_end
global parser_parse_assignments
global parser_begin_expression
global parser_tokenize

section .bss
cur_pos:    resq 1                  ; posicion actual en input_buf
cur_limit:  resq 1                  ; limite del tramo en analisis
expr_limit: resq 1                  ; fin de la expresion (coma de nivel 0)

section .text
; ----------------------------------------------------------------------------
; parser_begin_expression: prepara el analisis de la expresion principal.
; ----------------------------------------------------------------------------
parser_begin_expression:
    mov qword [cur_pos], 0
    mov rax, [expr_limit]
    mov [cur_limit], rax
    ret

; ----------------------------------------------------------------------------
; parser_find_expr_end: busca la primera coma fuera de parentesis y la guarda
;   en expr_limit.  Sin coma, expr_limit es el fin de la entrada.
; ----------------------------------------------------------------------------
parser_find_expr_end:
    lea rsi, [input_buf]
    mov rcx, [input_len]
    xor rdx, rdx                    ; profundidad de parentesis
    xor rax, rax                    ; indice
.loop:
    cmp rax, rcx
    jge .end
    movzx r8d, byte [rsi + rax]
    cmp r8b, '('
    jne .maybe_close
    inc rdx
    jmp .next
.maybe_close:
    cmp r8b, ')'
    jne .maybe_comma
    dec rdx
    jmp .next
.maybe_comma:
    cmp r8b, ','
    jne .next
    test rdx, rdx
    jnz .next
    mov [expr_limit], rax
    ret
.next:
    inc rax
    jmp .loop
.end:
    mov [expr_limit], rax
    ret

; ----------------------------------------------------------------------------
; peek: devuelve en al el caracter en cur_pos (0 si se paso del limite).
; advance: avanza cur_pos una posicion.
; skip_ws: salta espacios, tabs, CR y LF.
; ----------------------------------------------------------------------------
peek:
    mov rax, [cur_pos]
    cmp rax, [cur_limit]
    jge .past
    lea rsi, [input_buf]
    movzx eax, byte [rsi + rax]
    ret
.past:
    xor eax, eax
    ret

advance:
    inc qword [cur_pos]
    ret

skip_ws:
    lea rsi, [input_buf]
.loop:
    mov rax, [cur_pos]
    cmp rax, [cur_limit]
    jge .done
    movzx ecx, byte [rsi + rax]
    cmp cl, ' '
    je .skip
    cmp cl, 9
    je .skip
    cmp cl, 10
    je .skip
    cmp cl, 13
    je .skip
    ret
.skip:
    inc qword [cur_pos]
    jmp .loop
.done:
    ret

; ----------------------------------------------------------------------------
; parser_pre_operand: si el token anterior cierra un operando (NUM o ')'),
;   emite una multiplicacion implicita.
; ----------------------------------------------------------------------------
parser_pre_operand:
    mov rax, [tok_count]
    test rax, rax
    jz .ret
    dec rax
    shl rax, 5
    lea rcx, [tokens]
    mov rdx, [rcx + rax]
    cmp rdx, T_NUM
    je .implicit
    cmp rdx, T_RP
    je .implicit
.ret:
    ret
.implicit:
    mov edi, T_OP
    mov eax, '*'
    xor edx, edx
    call tok_add
    ret

; ----------------------------------------------------------------------------
; parser_is_exp_call: al = 1 si el caracter actual es 'e' seguido (ignorando
;   espacios) de '('.   Usa cur_pos.
; ----------------------------------------------------------------------------
parser_is_exp_call:
    mov rcx, [cur_pos]
    inc rcx
    mov r8, [cur_limit]
    lea r9, [input_buf]
.loop:
    cmp rcx, r8
    jge .no
    movzx edx, byte [r9 + rcx]
    cmp dl, ' '
    je .next
    cmp dl, 9
    je .next
    cmp dl, 10
    je .next
    cmp dl, 13
    je .next
    cmp dl, '('
    je .yes
    jmp .no
.next:
    inc rcx
    jmp .loop
.yes:
    mov al, 1
    ret
.no:
    xor eax, eax
    ret

; ----------------------------------------------------------------------------
; parser_scan_digits: recorre digitos desde cur_pos.
;   -> rax = posicion del primer caracter que no es digito
; ----------------------------------------------------------------------------
parser_scan_digits:
    mov rax, [cur_pos]
    mov r8, [cur_limit]
    lea r9, [input_buf]
.loop:
    cmp rax, r8
    jge .done
    movzx ecx, byte [r9 + rax]
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    inc rax
    jmp .loop
.done:
    ret

; ----------------------------------------------------------------------------
; parser_parse_assignments: lee "nombre = [+|-] digitos" separadas por comas
;   y las guarda en la tabla de variables (valor escalado si FIXED2).
; ----------------------------------------------------------------------------
parser_parse_assignments:
    push rbx
    push r12
    push r13
    push r14
    mov rax, [expr_limit]
    mov [cur_pos], rax
    mov rax, [input_len]
    mov [cur_limit], rax
.loop:
    call skip_ws
    call peek
    test al, al
    jz .done
    cmp al, ','
    jne .name
    call advance
    jmp .loop
.name:
    ; debe ser una letra
    cmp al, 'a'
    jl .upper
    cmp al, 'z'
    jle .have_name
.upper:
    cmp al, 'A'
    jl .invalid
    cmp al, 'Z'
    jg .invalid
.have_name:
    movzx r12d, al
    call advance
    call skip_ws
    call peek
    cmp al, '='
    jne .invalid
    call advance
    call skip_ws
    xor r14d, r14d                  ; signo
    call peek
    cmp al, '-'
    jne .maybe_plus
    mov r14d, 1
    call advance
    call skip_ws
    jmp .digits
.maybe_plus:
    cmp al, '+'
    jne .digits
    call advance
    call skip_ws
.digits:
    call peek
    cmp al, '0'
    jb .invalid
    cmp al, '9'
    ja .invalid
    call parser_scan_digits
    mov r13, rax                    ; fin de los digitos
    mov rsi, rax
    sub rsi, [cur_pos]              ; longitud
    mov rdi, [cur_pos]
    lea rax, [input_buf]
    add rdi, rax
    call io_dec_to_u128             ; rax:rdx = valor
    mov [cur_pos], r13
    test r14d, r14d
    jz .scale
    neg rax
    adc rdx, 0
    neg rdx
.scale:
%ifdef FIXED2
    mov rcx, SCALE
    xor ebx, ebx
    call mul_128
%endif
    mov edi, r12d
    call store_var
    jmp .loop
.invalid:
    mov edi, ERR_INVALID
    call report_error
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; parser_tokenize: convierte la expresion [cur_pos, cur_limit) en tokens.
;   Sustituye las variables por su valor y valida la sintaxis.
;   Estados: r12 = esperando operando (1) / tras operando (0)
;            r13 = profundidad de parentesis
; ----------------------------------------------------------------------------
parser_tokenize:
    push rbx
    push r12
    push r13
    push r14
    push r15
    call tok_reset
    mov r12d, 1                     ; al principio se espera un operando
    xor r13d, r13d                  ; profundidad 0
.loop:
    call skip_ws
    call peek
    test al, al
    jz .end
    cmp al, '0'
    jb .not_digit
    cmp al, '9'
    ja .not_digit

    ; ---------------- numero entero literal ----------------
    call parser_pre_operand
    call parser_scan_digits
    mov rbx, rax                    ; fin
    mov rsi, rax
    sub rsi, [cur_pos]
    mov rdi, [cur_pos]
    lea rax, [input_buf]
    add rdi, rax
    call io_dec_to_u128             ; rax:rdx
    mov [cur_pos], rbx
%ifdef FIXED2
    mov rcx, SCALE
    xor ebx, ebx
    call mul_128
%endif
    mov edi, T_NUM
    call tok_add
    xor r12d, r12d
    jmp .loop

.not_digit:
    ; ---------------- parentesis, operadores, variables ----------------
    cmp al, '('
    je .open_paren
    cmp al, ')'
    je .close_paren
    cmp al, '+'
    je .plus
    cmp al, '-'
    je .minus
    cmp al, '*'
    je .star
    cmp al, '/'
    je .slash
    cmp al, '%'
    je .other_op
    cmp al, '^'
    je .other_op
    ; letra?
    cmp al, 'a'
    jl .upper_letter
    cmp al, 'z'
    jle .letter
.upper_letter:
    cmp al, 'A'
    jl .invalid
    cmp al, 'Z'
    jg .invalid

.letter:
    cmp al, 'e'
    jne .variable
    call parser_is_exp_call
    test al, al
    jz .variable
    ; ---------------- funcion e(...) ----------------
    call parser_pre_operand
    mov edi, T_EXP
    xor eax, eax
    xor edx, edx
    call tok_add
    call advance                    ; consume la 'e'
    mov r12d, 1                     ; despues debe venir '('
    jmp .loop

.variable:
    call parser_pre_operand
    mov rdi, [cur_pos]
    lea rax, [input_buf]
    movzx edi, byte [rax + rdi]
    call lookup_var                 ; rax:rdx = valor sustituido
    call advance
    mov edi, T_NUM
    call tok_add
    xor r12d, r12d
    jmp .loop

.open_paren:
    call parser_pre_operand
    mov edi, T_LP
    xor eax, eax
    xor edx, edx
    call tok_add
    inc r13
    call advance
    mov r12d, 1
    jmp .loop

.close_paren:
    test r12d, r12d
    jnz .invalid                    ; parentesis vacio o tras operador
    test r13, r13
    jz .invalid                     ; parentesis sin abrir
    mov edi, T_RP
    xor eax, eax
    xor edx, edx
    call tok_add
    dec r13
    call advance
    xor r12d, r12d
    jmp .loop

.plus:
    test r12d, r12d
    jz .binary_op
    call advance                    ; '+' unario: se ignora
    jmp .loop

.minus:
    test r12d, r12d
    jz .binary_op
    mov edi, T_NEG                  ; '-' unario
    xor eax, eax
    xor edx, edx
    call tok_add
    call advance
    jmp .loop                       ; sigue esperando operando

.star:
    test r12d, r12d
    jnz .invalid
    ; '**' es potencia
    mov rax, [cur_pos]
    inc rax
    cmp rax, [cur_limit]
    jge .plain_star
    lea rsi, [input_buf]
    movzx edx, byte [rsi + rax]
    cmp dl, '*'
    jne .plain_star
    mov edi, T_OP
    mov eax, '^'
    xor edx, edx
    call tok_add
    add qword [cur_pos], 2
    mov r12d, 1
    jmp .loop
.plain_star:
    mov edi, T_OP
    mov eax, '*'
    xor edx, edx
    call tok_add
    call advance
    mov r12d, 1
    jmp .loop

.slash:
    test r12d, r12d
    jnz .invalid
    mov edi, T_OP
    mov eax, '/'
    xor edx, edx
    call tok_add
    call advance
    mov r12d, 1
    jmp .loop

.other_op:
    test r12d, r12d
    jnz .invalid                    ; '%' y '^' no son unarios
.binary_op:
    mov edi, T_OP
    movzx edx, al
    mov rax, rdx
    xor edx, edx
    call tok_add
    call advance
    mov r12d, 1
    jmp .loop

.end:
    test r12d, r12d
    jnz .invalid                    ; termina esperando operando
    test r13, r13
    jnz .invalid                    ; parentesis sin cerrar
    cmp qword [tok_count], 0
    je .invalid
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov edi, ERR_INVALID
    call report_error

section .note.GNU-stack noalloc noexec nowrite progbits
