@  Hola Mundo para ARM en la Raspberry Pi
@      as hola_mundo.s -o hola_mundo.o
@      ld hola_mundo.o -o hola_mundo
@      ./hola_mundo

.section .data
mensaje:
    .ascii "Hola Mundo\n"          @ Hola Mundo, con new line
    .equ long_msg, . - mensaje     @ calcula cuantos bytes ocupa el hola mundo

.section .text
.global _start                     @ punto de entrada visible para el linker

_start:
    @syscall write: imprime el mensaje
    mov     r7, #4              @ numero de syscall: 4 = write
    mov     r0, #1              @ primer argumento:  1 = STDOUT (pantalla)
    ldr     r1, =mensaje        @ segundo argumento: direccion del texto a imprimir
    ldr     r2, =long_msg       @ tercer argumento:  cuantos bytes imprimir
    svc     0                   @ le pide al kernel que ejecute el write

    @syscall exit: termina
    mov     r7, #1              @ numero de syscall: 1 = exit
    mov     r0, #0              @ codigo de salida = 0
    svc     0                   @ le pide al kernel que termine el proceso
