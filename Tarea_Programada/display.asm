; ============================================================================
; display.asm - Impresion del resultado, paso a paso y precision decimal
; ----------------------------------------------------------------------------
; QUE HACE:
;   - renderiza la lista de tokens como texto (Extra 4) y guarda hasta 20
;     estados de simplificacion de 1024 caracteres en un buffer de BSS;
;   - imprime esos estados, uno por linea, antes del resultado;
;   - imprime el resultado: como entero de 128 bits (print_number) o en punto
;     fijo con 2 decimales (print_fixed2, Extra 5) sin usar FPU.
;
; EXPORTA (global): display_reset_steps, display_record_step,
;                   display_print_steps, print_steps (alias),
;                   print_number, print_fixed2
; IMPORTA (extern): io_write, io_u128_to_dec  (io.asm)
;                   udiv_128                  (operations.asm)
;                   tokens, tok_count         (evaluator.asm)
;
; Convencion System V AMD64:
;   print_number (rdx:rax = valor 128 bits)
;   print_fixed2 (rdi = valor escalado x100)  -> "81.66", "81.06"
; ============================================================================
BITS 64
DEFAULT REL

%ifdef FIXED2
SCALE       equ 100
NUM_DECIMAL equ 2                   ; los pasos muestran 2 decimales
%else
SCALE       equ 1
NUM_DECIMAL equ 0
%endif

; Tipos de token compartidos con parser.asm y evaluator.asm
T_NUM equ 1
T_OP  equ 2
T_LP  equ 3
T_RP  equ 4
T_NEG equ 5
T_EXP equ 6

MAX_STEPS equ 20
STEP_SIZE equ 1024

extern io_write
extern io_u128_to_dec
extern udiv_128
extern tokens
extern tok_count

global display_reset_steps
global display_record_step
global display_print_steps
global print_steps
global print_number
global print_fixed2

section .bss
step_buf:   resb MAX_STEPS * STEP_SIZE
step_len:   resq MAX_STEPS
step_count: resq 1
out_buf:    resb 64                 ; resultado final y numeros sueltos

section .data
newline_char: db 10

section .text
; ----------------------------------------------------------------------------
; display_reset_steps: olvida los pasos guardados.
; ----------------------------------------------------------------------------
display_reset_steps:
    mov qword [step_count], 0
    ret

; ----------------------------------------------------------------------------
; display_record_step: renderiza el estado actual de la lista de tokens y lo
;   guarda como un paso (omite el paso si es identico al anterior).
; ----------------------------------------------------------------------------
display_record_step:
    push rbx
    push r12
    push r13
    push r14
    mov rax, [step_count]
    cmp rax, MAX_STEPS
    jae .done
    mov r13, rax
    shl rax, 10                     ; * 1024
    lea rdi, [step_buf]
    add rdi, rax
    mov r14, rdi                    ; ranura nueva
    call render_tokens              ; rax = longitud
    mov r12, rax
    test r13, r13
    jz .store
    lea rcx, [step_len]
    mov rdx, [rcx + r13 * 8 - 8]    ; longitud del paso anterior
    cmp rdx, r12
    jne .store
    test r12, r12
    jz .done
    mov rax, r13
    dec rax
    shl rax, 10
    lea rsi, [step_buf]
    add rsi, rax
    mov rdi, r14
    mov rcx, r12
    repe cmpsb
    je .done                        ; repetido: no se guarda
.store:
    lea rcx, [step_len]
    mov [rcx + r13 * 8], r12
    inc qword [step_count]
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; print_steps: alias del enunciado del Extra 4 para imprimir la secuencia.
; ----------------------------------------------------------------------------
print_steps:
    jmp display_print_steps

; ----------------------------------------------------------------------------
; display_print_steps: imprime cada paso guardado en su propia linea.
; ----------------------------------------------------------------------------
display_print_steps:
    push r12
    push r13
    xor r12d, r12d
.loop:
    cmp r12, [step_count]
    jge .done
    mov rax, r12
    shl rax, 10
    lea rdi, [step_buf]
    add rdi, rax
    lea rcx, [step_len]
    mov rsi, [rcx + r12 * 8]
    call io_write
    lea rdi, [newline_char]
    mov esi, 1
    call io_write
    inc r12
    jmp .loop
.done:
    pop r13
    pop r12
    ret

; ----------------------------------------------------------------------------
; print_number: imprime rax:rdx como entero decimal + salto de linea.
; ----------------------------------------------------------------------------
print_number:
    push rbx
    push r12
    mov r12, rax
    mov rbx, rdx
    lea rdi, [out_buf]
    mov ecx, 0                      ; sin decimales
    call render_value               ; rax = longitud
    lea rdi, [out_buf]
    mov rsi, rax
    call io_write
    lea rdi, [newline_char]
    mov esi, 1
    call io_write
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; print_fixed2: imprime rdi (escalado x100) con 2 decimales + salto de linea.
;   Ejemplo: 8166 -> "81.66", 8106 -> "81.06", -8166 -> "-81.66".
; ----------------------------------------------------------------------------
print_fixed2:
    push rbx
    push r12
    mov rax, rdi
    mov rdx, rdi
    sar rdx, 63                     ; extension de signo a 128 bits
    lea rdi, [out_buf]
    mov ecx, 2                      ; siempre 2 decimales
    call render_value
    lea rdi, [out_buf]
    mov rsi, rax
    call io_write
    lea rdi, [newline_char]
    mov esi, 1
    call io_write
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; render_value: convierte un entero de 128 bits a texto decimal.
;   rdi = destino, rdx:rax = valor, ecx = decimales (0 o 2)
;   -> rax = longitud escrita (termina en NUL)
; ----------------------------------------------------------------------------
render_value:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov [rsp], rdi                  ; base del destino
    mov [rsp + 8], rcx              ; decimales pedidos
    mov rbp, rdi                    ; cursor
    mov r12, rax                    ; magnitud baja
    mov r13, rdx                    ; magnitud alta
    test r13, r13
    jns .positive
    mov byte [rbp], '-'
    inc rbp
    neg r12
    adc r13, 0
    neg r13                         ; valor absoluto (128 bits)
.positive:
    cmp qword [rsp + 8], 0
    jne .fixed
    mov rax, r12
    mov rdx, r13
    mov rdi, rbp
    call io_u128_to_dec
    add rbp, rax
    jmp .done
.fixed:
    mov rax, r12
    mov rdx, r13
    mov rcx, 100
    xor ebx, ebx
    call udiv_128                   ; cociente r10:r11, resto r8:r9
    mov r15, r8                     ; parte fraccionaria (0..99)
    mov rax, r10
    mov rdx, r11
    mov rdi, rbp
    call io_u128_to_dec             ; parte entera
    add rbp, rax
    mov byte [rbp], '.'
    inc rbp
    mov rax, r15
    xor edx, edx
    mov rcx, 10
    div rcx                         ; al = decenas, dl = unidades
    add al, '0'
    mov [rbp], al
    add dl, '0'
    mov [rbp + 1], dl
    add rbp, 2
.done:
    mov byte [rbp], 0
    mov rax, rbp
    sub rax, [rsp]
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

; ----------------------------------------------------------------------------
; render_tokens: escribe la expresion actual como texto (Extra 4).
;   rdi = destino -> rax = longitud
; ----------------------------------------------------------------------------
render_tokens:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi                        ; guarda el destino
    mov r12, rdi                    ; cursor de escritura
    mov r15, rdi
    add r15, STEP_SIZE - 48         ; deja margen para un numero completo
    lea r14, [tokens]
    xor r13d, r13d                  ; indice de token
.loop:
    cmp r13, [tok_count]
    jge .done
    cmp r12, r15
    jae .done
    mov rbx, r13
    shl rbx, 5
    mov rax, [r14 + rbx]
    cmp rax, T_NUM
    je .num
    cmp rax, T_OP
    je .op
    cmp rax, T_LP
    je .open
    cmp rax, T_RP
    je .close
    cmp rax, T_NEG
    je .neg
    ; T_EXP
    mov byte [r12], 'e'
    inc r12
    jmp .next
.num:
    mov rax, [r14 + rbx + 8]
    mov rdx, [r14 + rbx + 16]
    mov rdi, r12
    mov ecx, NUM_DECIMAL
    call render_value
    add r12, rax
    jmp .next
.op:
    mov r11, [r14 + rbx + 8]        ; caracter del operador
    cmp r11b, '+'
    je .spaced
    cmp r11b, '-'
    je .spaced
    mov [r12], r11b
    inc r12
    jmp .next
.spaced:
    test r13, r13
    jz .no_lead
    mov rax, r13
    shl rax, 5
    mov rdx, [r14 + rax - 32]       ; tipo del token anterior
    cmp rdx, T_LP
    je .no_lead
    mov byte [r12], ' '
    inc r12
.no_lead:
    mov [r12], r11b
    inc r12
    mov byte [r12], ' '
    inc r12
    jmp .next
.open:
    mov byte [r12], '('
    inc r12
    jmp .next
.close:
    mov byte [r12], ')'
    inc r12
    jmp .next
.neg:
    mov byte [r12], '-'
    inc r12
.next:
    inc r13
    jmp .loop
.done:
    mov byte [r12], 0
    mov rax, r12
    sub rax, [rsp]
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
