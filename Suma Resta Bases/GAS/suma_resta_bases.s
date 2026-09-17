@ Tarea Corta 03 - Parte 1 (Actividad 2)
@ Julian Solorzano y Abril Gonzales

.syntax unified
.cpu cortex-a7
.arm

.equ SYS_EXIT,  1
.equ SYS_READ,  3
.equ SYS_WRITE, 4
.equ STDIN,     0
.equ STDOUT,    1
.equ MAX_IN,    12
.equ OUTBUF_LEN, 40

.data
msg_num1:     .asciz "Ingrese el primer numero: "
msg_num2:     .asciz "Ingrese el segundo numero: "
msg_error:    .asciz "Error: Entrada invalida. Por favor ingrese un numero valido.\n"
msg_sum:      .asciz "  Suma: "
msg_sub:      .asciz "  Resta: "
str_base:     .asciz "\n La base es: "
str_base_end: .asciz "=\n"
newline:      .asciz "\n"
minus_sign:   .asciz "-"
digitos:      .asciz "0123456789ABCDEF"

.bss
inbuf_1:   .space MAX_IN
inbuf_2:   .space MAX_IN
outbuf:    .space OUTBUF_LEN

val1:      .space 4
val2:      .space 4
res_sum:   .space 4
res_sub:   .space 4
is_neg:    .space 1

.text
.global _start

_start:
    @ Leer el primer número
    ldr r0, =msg_num1
    ldr r1, =inbuf_1
    bl read_number_safe
    ldr r1, =val1
    str r0, [r1]

    @ Leer el segundo número
    ldr r0, =msg_num2
    ldr r1, =inbuf_2
    bl read_number_safe
    ldr r1, =val2
    str r0, [r1]

    @ Calcular la suma
    ldr r0, =val1
    ldr r0, [r0]
    ldr r1, =val2
    ldr r1, [r1]
    add r2, r0, r1
    ldr r3, =res_sum
    str r2, [r3]

    @ Calcular la diferencia val1 - val2
    subs r2, r0, r1
    bmi .sub_negative           @ si el resultado es negativo...

    ldr r3, =is_neg
    mov r0, #0
    strb r0, [r3]
    b .save_sub

.sub_negative:
    rsb r2, r2, #0              @ obtener la magnitud positiva
    ldr r3, =is_neg
    mov r0, #1
    strb r0, [r3]

.save_sub:
    ldr r3, =res_sub
    str r2, [r3]

    @ Recorrer las bases 2 a 16
    mov r4, #2                  @ base actual

.loop_bases:
    cmp r4, #16
    bgt .exit

    @ Mostrar separador e indicar la base
    ldr r0, =str_base
    bl print_string
    mov r0, r4
    mov r1, #10
    bl to_base
    bl print_string
    ldr r0, =str_base_end
    bl print_string

    @ Mostrar la suma en la base actual
    ldr r0, =msg_sum
    bl print_string
    ldr r0, =res_sum
    ldr r0, [r0]
    mov r1, r4
    bl to_base
    bl print_string
    ldr r0, =newline
    bl print_string

    @ Mostrar la resta en la base actual
    ldr r0, =msg_sub
    bl print_string
    ldr r0, =is_neg
    ldrb r0, [r0]
    cmp r0, #1
    bne .print_sub_val
    ldr r0, =minus_sign
    bl print_string

.print_sub_val:
    ldr r0, =res_sub
    ldr r0, [r0]
    mov r1, r4
    bl to_base
    bl print_string
    ldr r0, =newline
    bl print_string

    add r4, r4, #1
    b .loop_bases

.exit:
    mov r0, #0
    mov r7, #SYS_EXIT
    svc #0

@ Subrutina: print_string
@ R0 = dirección de una cadena terminada en 0

print_string:
    push {r0, r1, r2, r7, lr}
    mov r1, r0                  @ r1 = buffer
    mov r2, #0                  @ r2 = longitud

.len_loop:
    ldrb r3, [r1, r2]
    cmp r3, #0
    beq .do_print
    add r2, r2, #1
    b .len_loop

.do_print:
    mov r0, #STDOUT
    mov r7, #SYS_WRITE
    svc #0
    pop {r0, r1, r2, r7, pc}

@ Subrutina: to_base
@ Convierte un entero sin signo a una cadena en la base indicada.
@ R0 = número a convertir
@ R1 = base destino (2 a 16)
@ Devuelve en R0 la dirección del texto generado en outbuf

to_base:
    push {r1, r2, r3, r4, r5, lr}
    ldr r2, =outbuf
    add r2, r2, #(OUTBUF_LEN - 1)
    mov r3, #0
    strb r3, [r2]               @ terminador nulo

    cmp r0, #0
    bne .itoa_loop_arm
    sub r2, r2, #1
    mov r3, #'0'
    strb r3, [r2]
    b .itoa_done_arm

.itoa_loop_arm:
    cmp r0, #0
    beq .itoa_done_arm

    udiv r3, r0, r1             @ r3 = cociente
    mls r4, r3, r1, r0          @ r4 = residuo = r0 - (r3 * r1)

    ldr r5, =digitos
    ldrb r4, [r5, r4]           @ convertir el residuo a su dígito ASCII
    sub r2, r2, #1
    strb r4, [r2]

    mov r0, r3                  @ continuar con el cociente
    b .itoa_loop_arm

.itoa_done_arm:
    mov r0, r2                  @ devolver el inicio de la cadena
    pop {r1, r2, r3, r4, r5, pc}

@ Subrutina: read_number_safe
@ Lee un número decimal, lo valida y lo convierte a entero.
@ R0 = mensaje a mostrar
@ R1 = buffer donde se guarda la entrada
@ Devuelve el número convertido en R0
read_number_safe:
    push {r4, r5, r6, r7, lr}
    mov r4, r0                  @ conservar el mensaje
    mov r5, r1                  @ conservar el buffer

.retry_arm:
    mov r0, r4
    bl print_string

    mov r0, #STDIN
    mov r1, r5
    mov r2, #MAX_IN
    sub r2, r2, #1              @ dejar espacio para el terminador o el '\n'
    mov r7, #SYS_READ
    svc #0

    cmp r0, #1
    ble .invalid_arm            @ si no se leyó nada útil, reintentar

    mov r2, #0                  @ índice dentro del buffer
    mov r3, #0                  @ acumulador del número

.parse_arm:
    ldrb r6, [r5, r2]
    cmp r6, #10                 @ fin de línea
    beq .success_arm
    cmp r6, #0
    beq .success_arm

    @ aceptar solo dígitos '0'..'9'
    cmp r6, #'0'
    blt .invalid_arm
    cmp r6, #'9'
    bgt .invalid_arm

    sub r6, r6, #'0'            @ ASCII a valor numérico
    mov r7, #10
    mul r3, r3, r7              @ r3 = r3 * 10
    add r3, r3, r6              @ r3 = r3 + dígito

    add r2, r2, #1
    b .parse_arm

.invalid_arm:
    ldr r0, =msg_error
    bl print_string
    b .retry_arm

.success_arm:
    mov r0, r3                  @ devolver el número en r0
    pop {r4, r5, r6, r7, pc}