@ Lee dos numeros por stdin, valida que sean solo digitos, e imprime
@ su suma y su resta en decimal. Si algo no es numerico, aborta con error.

.section .data
    msg_num1:  .asciz "Ingrese primer numero: "
    msg_num2:  .asciz "Ingrese segundo numero: "
    msg_sum:   .asciz "La suma es: "
    msg_sub:   .asciz "La resta es: "
    msg_error: .asciz "Error: Ingrese solo numeros.\n"

    .equ MAX_IN,    14     @ 10 digitos (<2^32) + margen
    .equ MAX_OUT,   13     @ 10 digitos + signo + '\n' + null
    .equ STDIN,     0
    .equ STDOUT,    1
    .equ SYS_READ,  3
    .equ SYS_WRITE, 4
    .equ SYS_EXIT,  1

.section .bss
    .lcomm buf1,   MAX_IN
    .lcomm buf2,   MAX_IN
    .lcomm outbuf, MAX_OUT

.section .text
.global _start

@ Imprime un string terminado en 0.
@ r0 = puntero al string.
@ No preserva r0-r3: son caller-saved en AAPCS, asi que quien llame esto
@ y necesite esos valores despues debe guardarlos antes.
print_string:
    mov     r1, r0
    mov     r2, #0
1:  ldrb    r3, [r1, r2]
    cmp     r3, #0
    beq     2f
    add     r2, r2, #1
    b       1b
2:  mov     r7, #SYS_WRITE
    mov     r0, #STDOUT
    swi     #0
    bx      lr

@ Pide un numero por pantalla, lo lee y lo convierte de texto a entero.
read_number:
    push    {r4, r5, lr}
    mov     r4, r1              @ guarda el puntero al buffer en un callee-saved,
                                @ asi sobrevive al bl sin importar que haga print_string

    bl      print_string

    mov     r7, #SYS_READ
    mov     r0, #STDIN
    mov     r1, r4
    mov     r2, #MAX_IN - 1
    swi     #0                  @ r0 = bytes leidos (incluye '\n')

    subs    r5, r0, #1          @ resta el '\n' que siempre viene al final
    ble     .Lread_err          @ si no quedo nada, el input estaba vacio

    mov     r0, #0              @ acumulador del numero
    mov     r2, #0              @ indice del caracter actual
.Lparse:
    cmp     r2, r5
    bge     .Lread_ok
    ldrb    r3, [r4, r2]
    cmp     r3, #'0'
    blt     .Lread_err
    cmp     r3, #'9'
    bgt     .Lread_err
    sub     r3, r3, #'0'
    mov     r1, #10
    mul     r0, r1, r0          @ orden r1,r0 (no r0,r0): Rd y Rm no deben coincidir en mul
    add     r0, r0, r3
    add     r2, r2, #1
    b       .Lparse

.Lread_ok:
    mov     r1, #0
    pop     {r4, r5, pc}
.Lread_err:
    mov     r1, #1
    pop     {r4, r5, pc}

@ Imprime un mensaje seguido del numero en decimal (con signo si es negativo).
@ r0 = mensaje, r1 = numero de 32 bits.
print_number:
    push    {r4, r5, r6, lr}
    mov     r4, r1              @ r0 se va a reusar para el mensaje, el numero se guarda aparte

    bl      print_string

    ldr     r5, =outbuf
    add     r5, r5, #MAX_OUT - 1
    mov     r6, #0
    strb    r6, [r5]            @ el string se arma de atras hacia adelante, terminando en 0

    mov     r6, #0              @ 1 si el numero es negativo, 0 si no
    cmp     r4, #0
    bge     .Lconv
    mov     r6, #1
    rsb     r4, r4, #0          @ a partir de aqui se trabaja con el valor absoluto

.Lconv:                         @ ARM no tiene division simple, asi que se hace
                                @ a mano: resta 10 repetidas veces para sacar
                                @ el cociente y el residuo de cada digito
    mov     r2, #0              @ cociente parcial
.Lsub:
    cmp     r4, #10
    blt     .Ldigit
    sub     r4, r4, #10
    add     r2, r2, #1
    b       .Lsub
.Ldigit:
    add     r3, r4, #'0'        @ lo que queda en r4 es el residuo: el digito actual
    sub     r5, r5, #1
    strb    r3, [r5]
    mov     r4, r2              @ el cociente es el numero que falta seguir dividiendo
    cmp     r4, #0
    bne     .Lconv

    cmp     r6, #0
    beq     .Lprint
    sub     r5, r5, #1
    mov     r2, #'-'
    strb    r2, [r5]            @ antepone el signo si era negativo

.Lprint:
    ldr     r2, =outbuf
    add     r2, r2, #MAX_OUT - 1
    sub     r2, r2, r5          @ longitud real del texto (varia segun el numero)
    mov     r1, r5
    mov     r0, #STDOUT
    mov     r7, #SYS_WRITE
    swi     #0

    ldr     r1, =outbuf
    mov     r6, #10
    strb    r6, [r1]            @ el numero ya se imprimio; se reusa outbuf[0] para el '\n'
    mov     r2, #1
    mov     r0, #STDOUT
    mov     r7, #SYS_WRITE
    swi     #0

    pop     {r4, r5, r6, pc}

_start:
    ldr     r0, =msg_num1
    ldr     r1, =buf1
    bl      read_number
    cmp     r1, #1
    beq     .Lerror
    mov     r4, r0              @ primer numero

    ldr     r0, =msg_num2
    ldr     r1, =buf2
    bl      read_number
    cmp     r1, #1
    beq     .Lerror
    mov     r5, r0              @ segundo numero

    ldr     r0, =msg_sum
    add     r1, r4, r5
    bl      print_number

    ldr     r0, =msg_sub
    sub     r1, r4, r5
    bl      print_number

    mov     r7, #SYS_EXIT
    mov     r0, #0
    swi     #0

.Lerror:
    ldr     r0, =msg_error
    bl      print_string
    mov     r7, #SYS_EXIT
    mov     r0, #1
    swi     #0
