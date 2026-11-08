; ============================================================
; IC3101 Tarea 2 — Evaluador de expresiones (núcleo obligatorio)
; x86-64 Linux / NASM / sin libc
; Compilar:  nasm -f elf64 main.asm -o main.o
; Enlazar:   ld main.o -o evaluator
; ADVERTENCIA: código no probado exhaustivamente.
; ============================================================
BITS 64
DEFAULT REL

SYS_READ  equ 0
SYS_WRITE equ 1
SYS_EXIT  equ 60
STDIN     equ 0
STDOUT    equ 1

MAX_INPUT equ 2048
MAX_VARS  equ 10

ERR_INVALID   equ 1
ERR_DIV0      equ 2
ERR_OVERFLOW  equ 3
ERR_UNDEF_VAR equ 4
ERR_TOOMANY   equ 5

section .bss
input_buf:   resb MAX_INPUT
input_len:   resq 1
cur_pos:     resq 1
cur_limit:   resq 1
expr_limit:  resq 1
out_buf:     resb 128
var_names:   resb MAX_VARS * 8
var_defined: resb MAX_VARS
var_vals:    resq MAX_VARS * 2
var_count:   resq 1

section .data
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

minus_char:   db '-'
newline_char: db 10

section .text
global _start
_start:
    xor eax, eax
    xor edi, edi
    lea rsi, [input_buf]
    mov edx, MAX_INPUT - 1
    mov rax, SYS_READ
    syscall
    test rax, rax
    jle .empty
    mov [input_len], rax
    lea rdi, [input_buf]
    mov rcx, rax
    mov byte [rdi + rcx], 0

    call find_expr_end
    call parse_assignments

    mov qword [cur_pos], 0
    mov rax, [expr_limit]
    mov [cur_limit], rax
    call parse_expression

    call print_128

    mov rax, SYS_EXIT
    xor edi, edi
    syscall
.empty:
    mov edi, ERR_INVALID
    call report_error

; ------------------- report_error ---------------------------
report_error:
    lea rsi, [err_msgs]
    mov rax, rdi
    shl rax, 4
    add rsi, rax
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rdx, [rsi + 8]
    mov rsi, [rsi]
    syscall
    mov rax, SYS_EXIT
    mov edi, 1
    syscall

; ------------------- find_expr_end --------------------------
find_expr_end:
    lea rsi, [input_buf]
    mov rcx, [input_len]
    xor rdx, rdx
    xor rax, rax
.loop:
    cmp rax, rcx
    jge .end
    movzx r8d, byte [rsi + rax]
    cmp r8b, '('
    jne .1
    inc rdx
    jmp .next
.1: cmp r8b, ')'
    jne .2
    dec rdx
    jmp .next
.2: cmp r8b, ','
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

; ------------------- peek / advance / skip_ws ---------------
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
    jmp .done
.skip:
    inc qword [cur_pos]
    jmp .loop
.done:
    ret

is_primary_start:
    call skip_ws
    call peek
    test al, al
    jz .no
    cmp al, '0'
    jl .cl
    cmp al, '9'
    jle .yes
.cl: cmp al, 'A'
    jl .clow
    cmp al, 'Z'
    jle .yes
.clow: cmp al, 'a'
    jl .cp
    cmp al, 'z'
    jle .yes
.cp: cmp al, '('
    je .yes
.no: xor eax, eax
    ret
.yes: mov al, 1
    ret

; ------------------- 128-bit signed arithmetic --------------
; Convenio: valor en rax (lo), rdx (hi)

add_128:                          ; rax:rdx += rcx:rbx
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
.ov: mov edi, ERR_OVERFLOW
    call report_error

sub_128:                          ; rax:rdx -= rcx:rbx
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
.ov: mov edi, ERR_OVERFLOW
    call report_error

neg_128:                          ; rax:rdx = -rax:rdx
    mov r8, 0x8000000000000000
    cmp rdx, r8
    jne .do
    test rax, rax
    jz .ov
.do: neg rax
    adc rdx, 0
    neg rdx
    ret
.ov: mov edi, ERR_OVERFLOW
    call report_error

mul_128:                          ; rax:rdx *= rcx:rbx
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
.a: mov r11, rbx
    mov rsi, rcx
    test r11, r11
    jns .b
    neg rsi
    adc r11, 0
    neg r11
.b: mov rax, r10
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
    js .ng
    test r10, r10
    js .ov
    mov rax, r12
    mov rdx, r10
    jmp .done
.ng: test r10, r10
    jns .dng
    mov r9, 0x8000000000000000
    cmp r10, r9
    jne .ov
    test r12, r12
    jnz .ov
    mov rax, 0
    mov rdx, r9
    jmp .done
.dng: mov rax, r12
    mov rdx, r10
    neg rax
    adc rdx, 0
    neg rdx
    jmp .done
.ov: mov edi, ERR_OVERFLOW
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

udiv_128:                         ; unsigned: r10:r11=q, r8:r9=r
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
    jb .ns
    cmp r8, rcx
    jb .ns
.sub:
    sub r8, rcx
    sbb r9, rbx
    or r10, 1
.ns: dec r12
    jnz .loop
    pop r12
    ret

div_128:                          ; rax:rdx /= rcx:rbx
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
.a: mov r15, rbx
    mov r14, rcx
    test r15, r15
    jns .b
    neg r14
    adc r15, 0
    neg r15
.b: mov rax, r12
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
.ok: ret
.dz: mov edi, ERR_DIV0
    call report_error
.ov: mov edi, ERR_OVERFLOW
    call report_error

; ------------------- Parser --------------------------------
parse_expression:                 ; expression := term (('+'|'-') term)*
    call parse_term
.loop:
    call skip_ws
    call peek
    cmp al, '+'
    je .ad
    cmp al, '-'
    je .sb
    ret
.ad: call advance
    push rdx
    push rax
    call parse_term
    pop rcx
    pop rbx
    call add_128
    jmp .loop
.sb: call advance
    push rdx
    push rax
    call parse_term
    pop rcx
    pop rbx
    xchg rax, rcx
    xchg rdx, rbx
    call sub_128
    jmp .loop

parse_term:                       ; term := unary (('*'|'/') unary | <impl> unary)*
    call parse_unary
.loop:
    call skip_ws
    call peek
    cmp al, '*'
    je .ml
    cmp al, '/'
    je .dv
    call is_primary_start
    test al, al
    jnz .im
    ret
.ml: call advance
    push rdx
    push rax
    call parse_unary
    pop rcx
    pop rbx
    call mul_128
    jmp .loop
.dv: call advance
    push rdx
    push rax
    call parse_unary
    pop rcx
    pop rbx
    xchg rax, rcx
    xchg rdx, rbx
    call div_128
    jmp .loop
.im: push rdx
    push rax
    call parse_unary
    pop rcx
    pop rbx
    call mul_128
    jmp .loop

parse_unary:                      ; unary := ('+'|'-') unary | power
    call skip_ws
    call peek
    cmp al, '-'
    je .ng
    cmp al, '+'
    je .ps
    jmp parse_power
.ng: call advance
    call parse_unary
    call neg_128
    ret
.ps: call advance
    call parse_unary
    ret

parse_power:                      ; power := primary ('**' unary)?
    call parse_primary
    push rdx
    push rax
    call skip_ws
    call peek
    cmp al, '*'
    jne .np
    mov rax, [cur_pos]
    inc rax
    cmp rax, [cur_limit]
    jge .np
    lea rsi, [input_buf]
    movzx eax, byte [rsi + rax]
    cmp al, '*'
    jne .np
    add qword [cur_pos], 2
    pop rax
    pop rdx
    push rdx
    push rax
    call parse_unary
    pop rcx
    pop rbx
    xchg rax, rcx
    xchg rdx, rbx
    call pow_128
    ret
.np: pop rax
    pop rdx
    ret

pow_128:                          ; rax:rdx = base^exp (base rax:rdx, exp rcx:rbx)
    push r12
    push r13
    push r14
    push r15
    push rbp
    test rbx, rbx
    js .bad
    mov r8, rcx
    or r8, rbx
    jz .one
    mov r8, rax
    or r8, rdx
    jz .zero
    test rbx, rbx
    jnz .ov
    cmp rcx, 200
    ja .ov
    mov r12, 1
    xor r13, r13
    mov r14, rax
    mov r15, rdx
    mov rbp, rcx
.loop:
    test rbp, rbp
    jz .done
    mov rax, r12
    mov rdx, r13
    mov rcx, r14
    mov rbx, r15
    call mul_128
    mov r12, rax
    mov r13, rdx
    dec rbp
    jmp .loop
.done:
    mov rax, r12
    mov rdx, r13
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    ret
.one:  mov rax, 1
       xor rdx, rdx
       jmp .epi
.zero: xor eax, eax
       xor edx, edx
       jmp .epi
.epi:  pop rbp
       pop r15
       pop r14
       pop r13
       pop r12
       ret
.bad:  mov edi, ERR_INVALID
       call report_error
.ov:   mov edi, ERR_OVERFLOW
       call report_error

parse_primary:                    ; primary := NUMBER | VAR | '(' expr ')'
    call skip_ws
    call peek
    test al, al
    jz .inv
    cmp al, '('
    je .par
    cmp al, '0'
    jl .cv
    cmp al, '9'
    jg .cv
    jmp parse_number
.cv: cmp al, 'a'
    jl .cu
    cmp al, 'z'
    jg .cu
    jmp parse_var
.cu: cmp al, 'A'
    jl .inv
    cmp al, 'Z'
    jg .inv
    jmp parse_var
.par: call advance
    call parse_expression
    call skip_ws
    call peek
    cmp al, ')'
    jne .inv
    call advance
    ret
.inv: mov edi, ERR_INVALID
    call report_error

parse_number:                     ; digits -> rax:rdx
    push r14
    push r15
    xor r14d, r14d
    xor r15d, r15d
.loop:
    call peek
    cmp al, '0'
    jl .done
    cmp al, '9'
    jg .done
    movzx r10d, al
    sub r10d, '0'
    push r10
    mov rax, r14
    mov rdx, r15
    mov rcx, 10
    xor ebx, ebx
    call mul_128
    pop r10
    add rax, r10
    adc rdx, 0
    mov r14, rax
    mov r15, rdx
    call advance
    jmp .loop
.done:
    mov rax, r14
    mov rdx, r15
    pop r15
    pop r14
    ret

parse_var:                        ; una letra -> valor
    call peek
    movzx edi, al
    call advance
    call lookup_var
    ret

lookup_var:                       ; dil=name -> rax:rdx
    push rbx
    push rcx
    push rsi
    xor ecx, ecx
.s:
    cmp rcx, [var_count]
    jge .nf
    lea rsi, [var_names]
    mov rbx, rcx
    shl rbx, 3
    cmp byte [rsi + rbx], dil
    je .f
    inc rcx
    jmp .s
.f: lea rsi, [var_defined]
    cmp byte [rsi + rcx], 0
    je .nf
    lea rsi, [var_vals]
    mov rbx, rcx
    shl rbx, 4
    mov rax, [rsi + rbx]
    mov rdx, [rsi + rbx + 8]
    pop rsi
    pop rcx
    pop rbx
    ret
.nf: mov edi, ERR_UNDEF_VAR
     call report_error

; ------------------- Asignaciones ---------------------------
parse_assignments:
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
    jne .tv
    call advance
    jmp .loop
.tv: cmp al, 'a'
    jl .tu
    cmp al, 'z'
    jg .tu
    jmp .gn
.tu: cmp al, 'A'
    jl .inv
    cmp al, 'Z'
    jg .inv
.gn: push r12
    mov r12b, al
    call advance
    call skip_ws
    call peek
    cmp al, '='
    jne .ip
    call advance
    call skip_ws
    xor r14d, r14d
    call peek
    cmp al, '-'
    jne .cp
    mov r14d, 1
    call advance
    call skip_ws
    jmp .pd
.cp: cmp al, '+'
    jne .pd
    call advance
    call skip_ws
.pd: call peek
    cmp al, '0'
    jl .ip
    cmp al, '9'
    jg .ip
    call parse_number
    test r14d, r14d
    jz .st
    neg rax
    adc rdx, 0
    neg rdx
.st: pop r12
    mov edi, r12d
    call store_var
    jmp .loop
.ip: pop r12
.inv: mov edi, ERR_INVALID
     call report_error
.done:
    pop r14
    ret

store_var:                        ; edi=name, rax:rdx=value
    push rbx
    push rcx
    push rsi
    xor ecx, ecx
.s:
    cmp rcx, [var_count]
    jge .an
    lea rsi, [var_names]
    mov rbx, rcx
    shl rbx, 3
    cmp byte [rsi + rbx], dil
    je .up
    inc rcx
    jmp .s
.up: lea rsi, [var_vals]
    mov rbx, rcx
    shl rbx, 4
    mov [rsi + rbx], rax
    mov [rsi + rbx + 8], rdx
    lea rsi, [var_defined]
    mov byte [rsi + rcx], 1
    jmp .done
.an: cmp qword [var_count], MAX_VARS
    jge .tm
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
.tm: mov edi, ERR_TOOMANY
     call report_error
.done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ------------------- Impresión ------------------------------
print_128:                        ; rax:rdx = valor signed
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    test rdx, rdx
    jns .pos
    push rax
    push rdx
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [minus_char]
    mov rdx, 1
    syscall
    pop rdx
    pop rax
    neg rax
    adc rdx, 0
    neg rdx
.pos:
    mov r12, rax
    mov r13, rdx
    lea rdi, [out_buf + 127]
    mov byte [rdi], 0
    mov rax, r12
    or rax, r13
    jnz .conv
    dec rdi
    mov byte [rdi], '0'
    jmp .wr
.conv:
    mov rax, r12
    mov rdx, r13
    mov rcx, 10
    xor ebx, ebx
    call udiv_128
    mov r12, r10
    mov r13, r11
    mov rax, r8
    add rax, '0'
    dec rdi
    mov [rdi], al
    mov rax, r12
    or rax, r13
    jnz .conv
.wr:
    lea rsi, [out_buf + 127]
    sub rsi, rdi
    mov rdx, rsi
    mov rsi, rdi
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    lea rsi, [newline_char]
    mov rdx, 1
    syscall
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret