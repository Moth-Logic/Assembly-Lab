; Lee dos numeros por stdin, valida que sean solo digitos, e imprime
; su suma y su resta en decimal. Si algo no es numerico, aborta con error.

section .data
    msg_num1  db "Ingrese primer numero: ", 0
    msg_num2  db "Ingrese segundo numero: ", 0
    msg_sum   db "La suma es: ", 0
    msg_sub   db "La resta es: ", 0
    msg_error db "Error: Ingrese solo numeros.", 10, 0

    SYS_READ  equ 0
    SYS_WRITE equ 1
    SYS_EXIT  equ 60
    STDIN     equ 0
    STDOUT    equ 1
    MAX_IN    equ 22      ; 20 digitos + '\n' + margen
    MAX_OUT   equ 24      ; 20 digitos + signo + '\n' + null

section .bss
    buf1      resb MAX_IN
    buf2      resb MAX_IN
    outbuf    resb MAX_OUT

section .text
    global _start

; Imprime un string terminado en 0.
; rdi = puntero al string.
print_string:
    xor     rcx, rcx
.len:
    cmp     byte [rdi + rcx], 0
    je      .go
    inc     rcx
    jmp     .len
.go:
    mov     rsi, rdi
    mov     rdi, STDOUT
    mov     rdx, rcx
    mov     rax, SYS_WRITE
    syscall
    ret

; Pide un numero por pantalla, lo lee y lo convierte de texto a entero.
read_number:
    push    r12            ; guarda el puntero al buffer en un registro callee-saved
    mov     r12, rsi        ; asi sobrevive al call sin importar que haga print_string

    call    print_string

    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, r12
    mov     rdx, MAX_IN - 1
    syscall                ; rax = bytes leidos (incluye '\n')

    dec     rax            ; descarta el '\n' que siempre viene al final
    jle     .error         ; si no quedo nada, el input estaba vacio

    xor     r8, r8         ; acumulador del numero
    xor     r9, r9         ; indice del caracter actual
.parse:
    cmp     r9, rax
    jge     .ok
    movzx   r10, byte [r12 + r9]
    cmp     r10, '0'
    jl      .error
    cmp     r10, '9'
    jg      .error
    sub     r10, '0'
    imul    r8, r8, 10
    add     r8, r10
    inc     r9
    jmp     .parse
.ok:
    mov     rax, r8
    pop     r12
    clc
    ret
.error:
    pop     r12
    stc
    ret

; Imprime un mensaje seguido del numero en decimal (con signo si es negativo).
; rdi = mensaje, rax = numero de 64 bits.
print_number:
    push    r12
    mov     r12, rax        ; print_string va a pisar rax, asi que el numero se guarda aparte

    call    print_string

    lea     rsi, [outbuf + MAX_OUT - 1]
    mov     byte [rsi], 0   ; el string se arma de atras hacia adelante, terminando en 0

    mov     rax, r12
    xor     r8, r8          ; 1 si el numero es negativo, 0 si no
    cmp     rax, 0
    jge     .conv
    mov     r8, 1
    neg     rax             ; a partir de aqui se trabaja con el valor absoluto
.conv:
    mov     rbx, 10
.loop:
    xor     rdx, rdx
    div     rbx             ; rax = rax / 10, rdx = residuo (el proximo digito)
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    test    rax, rax
    jnz     .loop           ; sigue mientras queden digitos

    test    r8, r8
    jz      .print
    dec     rsi
    mov     byte [rsi], '-' ; antepone el signo si era negativo

.print:
    lea     rdx, [outbuf + MAX_OUT - 1]
    sub     rdx, rsi        ; longitud real del texto (varia segun el numero)
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    syscall

    mov     byte [outbuf], 10   ; el numero ya se imprimio; se reusa outbuf[0] para el '\n'
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [outbuf]
    mov     rdx, 1
    syscall

    pop     r12
    ret

_start:
    mov     rdi, msg_num1
    mov     rsi, buf1
    call    read_number
    jc      .bad
    mov     r12, rax        ; primer numero (callee-saved: sobrevive la 2a lectura)

    mov     rdi, msg_num2
    mov     rsi, buf2
    call    read_number
    jc      .bad
    mov     r13, rax        ; segundo numero

    mov     rax, r12
    add     rax, r13
    mov     rdi, msg_sum
    call    print_number

    mov     rax, r12
    sub     rax, r13
    mov     rdi, msg_sub
    call    print_number

    mov     rax, SYS_EXIT
    xor     rdi, rdi
    syscall

.bad:
    mov     rdi, msg_error
    call    print_string
    mov     rax, SYS_EXIT
    mov     rdi, 1
    syscall
