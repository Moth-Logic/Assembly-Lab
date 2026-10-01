; Tarea Corta 03 - Parte 1 (Actividad 2)
;Julian Solorzano y Abril Gonzales

DEFAULT ABS

section .data
    msg_num1    db "Ingrese el primer numero: ", 0
    msg_num2    db "Ingrese el segundo numero: ", 0
    msg_error   db "Error: Entrada invalida. Por favor ingrese un numero valido.", 10, 0
    msg_sum     db "  Suma: ", 0
    msg_sub     db "  Resta: ", 0
    msg_mul     db "Multiplicacion: ", 0
    msg_mulbig  db "Multiplicacion: (rebasa, solo se muestra base 2,8 y 16)", 10, 0
    msg_div     db "Division: ", 0
    msg_divzero db "Division invalida", 10, 0
    str_base    db "Base = ", 0
    str_base_end db 10, 0
    newline     db 10, 0
    minus_sign  db "-", 0
    digitos     db "0123456789ABCDEF", 0

    SYS_READ    equ 0
    SYS_WRITE   equ 1
    SYS_EXIT    equ 60
    STDIN       equ 0
    STDOUT      equ 1
    OUTBUF_LEN  equ 130
    MAX_IN      equ 22

section .bss
    inbuf_1     resb MAX_IN
    inbuf_2     resb MAX_IN
    outbuf      resb OUTBUF_LEN

    val1        resq 1          ; primer número leído
    val2        resq 1          ; segundo número leído
    res_sum     resq 1          ; suma de ambos números
    res_sub     resq 1          ; diferencia en valor absoluto
    res_mul     resq 1          ; producto (RAX)
    res_mul_hi  resq 1          ; producto,  (RDX)
    res_div     resq 1          ; cociente
    div_ok      resb 1          ; 1 si se pudo dividir, 0 sino
    is_neg      resb 1          ; 1 si la resta dio negativa, 0 si no
 
section .text
    global _start

_start:
    ; Leer el primer número (validando que sea decimal)
    mov rdi, msg_num1
    mov rsi, inbuf_1
    call read_number_safe
    mov [val1], rax

    ; Leer el segundo número
    mov rdi, msg_num2
    mov rsi, inbuf_2
    call read_number_safe
    mov [val2], rax

    ; Calcular la suma
    mov rax, [val1]
    add rax, [val2]
    mov [res_sum], rax

    ; Calcular la diferencia val1 - val2
    mov rax, [val1]
    sub rax, [val2]
    jns .sub_pos                ; si el resultado no fue negativo...
    neg rax                     ; guardar la magnitud
    mov byte [is_neg], 1
    jmp .save_sub

.sub_pos:
    mov byte [is_neg], 0

.save_sub:
    mov [res_sub], rax

    ; Calcular la multiplicación: RDX:RAX = val1 * val2
    mov rax, [val1]
    mul qword [val2]
    mov [res_mul], rax          ; parte baja
    mov [res_mul_hi], rdx       ; parte alta


    ;Calcular la division entera
    mov rax, [val1]
    mov rcx, [val2]
    cmp rax, rcx
    jae .ordenados
    xchg rax, rcx               ; si val1 < val2, intercambiar

.ordenados:                     ; RAX = mayor, RCX = menor
    test rcx, rcx
    jz .div_cero                ; no se puede dividir entre 0
    xor rdx, rdx                ; DIV usa RDX:RAX
    div rcx                     ; RAX = cociente
    mov [res_div], rax
    mov byte [div_ok], 1
    jmp .div_fin

.div_cero:
    mov byte [div_ok], 0

.div_fin:
    ; Recorrer las bases 2 a 16
    mov r12, 2                  ; base actual

.loop_bases:
    cmp r12, 16
    jg .exit                    ; ya terminamos con la base 16

    ; Mostrar la etiqueta "Base = " indicando la base
    mov rdi, str_base
    call print_string
    mov rdi, r12
    mov rsi, 10
    call to_base
    mov rdi, rax
    call print_string
    mov rdi, str_base_end
    call print_string

    ; Mostrar la suma en la base actual
    mov rdi, msg_sum
    call print_string
    mov rdi, [res_sum]
    mov rsi, r12
    call to_base
    mov rdi, rax
    call print_string
    mov rdi, newline
    call print_string

    ; Mostrar la resta en la base actual
    mov rdi, msg_sub
    call print_string
    cmp byte [is_neg], 1
    jne .print_sub_val
    mov rdi, minus_sign         ; si la resta fue negativa, anteponer el signo
    call print_string

.print_sub_val:
    mov rdi, [res_sub]
    mov rsi, r12
    call to_base
    mov rdi, rax
    call print_string
    mov rdi, newline
    call print_string

    ; Mostrar la multiplicación en la base actual
    mov rdi, r12
    call print_mul

    ;Mostrar la division en la base actual
    mov rdi, r12 
    call print_div



    inc r12
    jmp .loop_bases

.exit:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall


; Subrutina: print_string
; RDI = dirección de una cadena terminada en 0

print_string:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    xor rcx, rcx
.len:
    cmp byte [rdi + rcx], 0
    je .go
    inc rcx
    jmp .len

.go:
    mov rsi, rdi                ; dirección del string a RSI
    mov rax, SYS_WRITE          ; sys_write
    mov rdi, STDOUT             ; stdout (1)
    mov rdx, rcx                ; longitud
    syscall

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Subrutina: print_div
; Imprime el cociente de la división entera en la base indicada.
; RDI = base actual (2 a 16)

print_div:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12

    mov r12, rdi                ; base actual

    cmp byte [div_ok], 1
    jne .cero

    mov rdi, msg_div
    call print_string
    mov rdi, [res_div]
    mov rsi, r12
    call to_base
    mov rdi, rax
    call print_string
    mov rdi, newline
    call print_string
    jmp .end

.cero:
    mov rdi, msg_divzero
    call print_string

.end:
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret




; Subrutina: print_mul
; Imprime la multiplicación en la base indicada.
; RDI = base actual (2 a 16)

print_mul:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12

    mov r12, rdi                ; base actual
    cmp qword [res_mul_hi], 0
    jne .high

    mov rdi, msg_mul            ; cabe en 64 bits: todas las bases
    call print_string
    mov rdi, [res_mul]
    mov rsi, r12
    call to_base
    mov rdi, rax
    call print_string
    mov rdi, newline
    call print_string
    jmp .end

.high:                          ; más de 64 bits: solo bases 2, 8 y 16
    cmp r12, 2
    je .pow2
    cmp r12, 8
    je .pow2
    cmp r12, 16
    je .pow2
    mov rdi, msg_mulbig
    call print_string
    jmp .end

.pow2:
    mov rdi, msg_mul
    call print_string
    mov rdi, [res_mul]          ; parte baja
    mov rsi, [res_mul_hi]       ; parte alta
    mov rdx, r12                ; base (2, 8 o 16)
    call to_pow2
    mov rdi, rax
    call print_string
    mov rdi, newline
    call print_string

.end:
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret


; Subrutina: to_base
; Convierte un entero sin signo a una cadena en la base indicada.
; RDI = número a convertir
; RSI = base destino (2 a 16)
; Devuelve en RAX la dirección del texto generado en outbuf

to_base:
    push rbx
    push rcx
    push rdx

    mov rax, rdi                ; copiar el número a dividir
    mov rbx, rsi                ; base usada como divisor
    lea rcx, [outbuf + OUTBUF_LEN - 1]
    mov byte [rcx], 0           ; cerrar la cadena

    cmp rax, 0
    jne .itoa_loop
    dec rcx
    mov byte [rcx], '0'
    jmp .done

.itoa_loop:
    cmp rax, 0
    je .done

    xor rdx, rdx                ; DIV usa RDX:RAX, así que limpiamos RDX
    div rbx                     ; RAX = cociente, RDX = residuo

    mov dl, byte [digitos + rdx]; convertir el residuo a su dígito ASCII
    dec rcx
    mov byte [rcx], dl          ; guardar el dígito al inicio del buffer
    jmp .itoa_loop

.done:
    mov rax, rcx                ; devolver el inicio de la cadena
    pop rdx
    pop rcx
    pop rbx
    ret


; Subrutina: to_pow2
; Convierte 128 bits a cadena en base 2, 8 o 16 usando desplazamientos.
; RDI = parte baja, RSI = parte alta, RDX = base
; Devuelve en RAX la dirección del texto generado en outbuf

to_pow2:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    mov rax, rdi                ; RAX = parte baja
    mov rbx, rsi                ; RBX = parte alta
    lea r8, [outbuf + OUTBUF_LEN - 1]
    mov byte [r8], 0            ; cerrar la cadena

    mov rcx, 1                  ; bits por dígito: base 2 -> 1
    cmp rdx, 8
    jne .no8
    mov rcx, 3                  ; base 8 -> 3
.no8:
    cmp rdx, 16
    jne .no16
    mov rcx, 4                  ; base 16 -> 4
.no16:
    dec rdx                     ; RDX = máscara (1, 7 o 15)

.loop:
    mov rsi, rax
    or rsi, rbx
    jz .done                    ; ambas partes en 0

    mov rdi, rax
    and rdi, rdx                ; los bits bajos son el dígito
    mov dil, byte [digitos + rdi]
    dec r8
    mov byte [r8], dil

    shrd rax, rbx, cl           ; desplaza los 128 bits a la derecha
    shr rbx, cl
    jmp .loop

.done:
    mov rax, r8                 ; devolver el inicio de la cadena
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret


; Subrutina: read_number_safe
; Lee un número decimal, valida y lo convierte a entero.
; RDI = mensaje a mostrar
; RSI = buffer donde se guarda la entrada
; Devuelve el número convertido en RAX

read_number_safe:
    push r12
    push r13
    push rbx
    push rcx
    push rdx

    mov r12, rdi                ; conservar el mensaje
    mov r13, rsi                ; conservar el buffer

.retry:
    mov rdi, r12
    call print_string

    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, r13
    mov rdx, MAX_IN - 1
    syscall

    cmp rax, 1
    jle .invalid                ; si no se leyó nada útil, reintentar

    ; conversión ASCII a entero
    xor rcx, rcx                ; índice dentro del buffer
    xor rax, rax                ; acumulador del número
    xor rbx, rbx                ; auxiliar para el dígito actual

.parse:
    mov bl, byte [r13 + rcx]    ; leer el carácter actual
    cmp bl, 10                  ; fin de línea
    je .success
    cmp bl, 0
    je .success

    ; aceptar solo dígitos '0'..'9'
    cmp bl, '0'
    jb .invalid
    cmp bl, '9'
    ja .invalid

    sub bl, '0'                 ; ASCII a valor numérico
    imul rax, 10                ; desplazar el acumulador una decena
    add rax, rbx                ; sumar el dígito actual

    inc rcx
    jmp .parse

.invalid:
    mov rdi, msg_error          ; avisar del error y volver a pedir
    call print_string
    jmp .retry

.success:
    pop rdx
    pop rcx
    pop rbx
    pop r13
    pop r12
    ret