; ==============================================================================
; Tarea Corta 03 - Parte 1 (Actividad 2)

section .data
    msg_num1    db "Ingrese el primer numero: ", 0
    msg_num2    db "Ingrese el segundo numero: ", 0
    msg_error   db "Error: Entrada invalida. Por favor ingrese un numero valido.", 10, 0
    msg_sum     db "  Suma: ", 0
    msg_sub     db "  Resta: ", 0
    str_base    db 10, "--- La base es: ", 0
    str_base_end db " ---", 10, 0
    newline     db 10, 0
    minus_sign  db "-", 0
    digitos     db "0123456789ABCDEF", 0

    SYS_READ    equ 0
    SYS_WRITE   equ 1
    SYS_EXIT    equ 60
    STDIN       equ 0
    STDOUT      equ 1
    OUTBUF_LEN  equ 80
    MAX_IN      equ 22

section .bss
    inbuf_1     resb MAX_IN
    inbuf_2     resb MAX_IN
    outbuf      resb OUTBUF_LEN
    
    val1        resq 1          ; primer número leído
    val2        resq 1          ; segundo número leído
    res_sum     resq 1          ; suma de ambos números
    res_sub     resq 1          ; diferencia en valor absoluto
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

    ; Recorrer las bases 2 a 16
    mov r12, 2                  ; base actual

.loop_bases:
    cmp r12, 16
    jg .exit                    ; ya terminamos con la base 16

    ; Mostrar separador e indicar la base
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