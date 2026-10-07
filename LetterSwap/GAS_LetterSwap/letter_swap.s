@ Build:
@   as -o case_swap.o case_swap.s
@   ld -o case_swap case_swap.o

.equ UPPER_LO, 0x41        @ 'A'
.equ UPPER_HI, 0x5A        @ 'Z'
.equ LOWER_LO, 0x61        @ 'a'
.equ LOWER_HI, 0x7A        @ 'z'
.equ CASE_BIT, 0x20        @ bit que distingue mayus de minus

.section .data
prompt:
    .ascii "Insert your message: "
    .equ prompt_len, . - prompt

.section .bss
    .lcomm buffer, 101      @ 100 chars max + '\n'

.section .text
.global _start

_start:
    @imprime el prompt
    mov r7, #4              @ syscall write
    mov r0, #1              @ fd 1 = stdout
    ldr r1, =prompt
    ldr r2, =prompt_len
    svc 0

    @lee el mensaje del usuario
    mov r7, #3              @ syscall read
    mov r0, #0              @ fd 0 = stdin
    ldr r1, =buffer
    mov r2, #101
    svc 0                   @ r0 = bytes realmente leidos

    mov r4, r0               @ r4 = limite del loop (longitud real)
    mov r5, #0               @ r5 = indice actual
    ldr r6, =buffer          @ r6 = direccion base del buffer


.convert_loop:
    cmp r5, r4
    bge .done_convert

    ldrb r0, [r6, r5]        @ PASO 1: cargar el byte

    cmp r0, #UPPER_LO
    blt .check_lower
    cmp r0, #UPPER_HI
    bgt .check_lower
    eor r0, r0, #CASE_BIT    @ eor = xor en ARM
    strb r0, [r6, r5]        @ guardar de vuelta en memoria
    b .next_char

.check_lower:
    cmp r0, #LOWER_LO
    blt .next_char
    cmp r0, #LOWER_HI
    bgt .next_char
    eor r0, r0, #CASE_BIT
    strb r0, [r6, r5]

.next_char:
    add r5, r5, #1
    b .convert_loop

.done_convert:
    @imprime el buffer convertido (longitud real)
    mov r7, #4
    mov r0, #1
    ldr r1, =buffer
    mov r2, r4
    svc 0

    @ exit(0)
    mov r7, #1
    mov r0, #0
    svc 0