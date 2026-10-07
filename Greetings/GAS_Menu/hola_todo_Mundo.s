@  Hola Mundo para ARM en la Raspberry Pi
@  IC-3101 Arquitectura de Computadoras - Tarea Corta 01 Parte 2
@      as hola_todo_Mundo.s -o hola_todo_Mundo.o
@      ld hola_todo_Mundo.o -o hola_todo_Mundo
@      ./hola_todo_Mundo


.section .data
@ el menu
menu:
    .ascii "\n"
    .ascii "Seleccione un mensaje:\n"
    .ascii "  a. Hola Mundo!!!\n"
    .ascii "  b. Feliz Dia del Amor y la Amistad!!!\n"
    .ascii "  c. Feliz Navidad!!!\n"
    .ascii "  d. Feliz Dia de la Independencia!!!\n"
    .ascii "  e. Otro (ingrese su propio mensaje)\n"
    .ascii "  f. Finalizar el programa\n"
    .ascii "Opcion: "
    .equ len_menu, . - menu        @ longitud total del menu (bytes)

@ mensajes
msg_a:
    .ascii "Hola Mundo!!!\n"
    .equ len_a, . - msg_a
msg_b:
    .ascii "Feliz Dia del Amor y la Amistad!!!\n"
    .equ len_b, . - msg_b
msg_c:
    .ascii "Feliz Navidad!!!\n"
    .equ len_c, . - msg_c
msg_d:
    .ascii "Feliz Dia de la Independencia!!!\n"
    .equ len_d, . - msg_d

@ el mensaje personalizado
prompt_propio:
    .ascii "Ingrese su propio mensaje: "
    .equ len_propio, . - prompt_propio

@ pregunta si quieres ver otro mensaje
prompt_continuar:
    .ascii "\n"
    .ascii "Desea ver otro mensaje?\n"
    .ascii "  1. Si\n"
    .ascii "  2. No, finalizar\n"
    .ascii "Opcion: "
    .equ len_continuar, . - prompt_continuar

@ error, si se esocge algo que no es abcdef
msg_invalida:
    .ascii "Opcion invalida, intente de nuevo.\n"
    .equ len_invalida, . - msg_invalida

@ chau
msg_despedida:
    .ascii "\nchau!.\n"
    .equ len_despedida, . - msg_despedida

.section .bss
    .lcomm buf_opcion, 2        @ guarda la opcion del menu
    .lcomm buf_mensaje, 256     @ guarda el mensaje personalizado (opcion e)
    .lcomm buf_continuar, 2     @ guarda la respuesta de "otro mensaje"

.section .text
.global _start


@ _start: bucle principal del programa

_start:
mostrar_menu:
    @ print menu
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =menu
    ldr     r2, =len_menu
    svc     0

    @ lee lo que quiere ek usuario
    mov     r7, #3              @ syscall read
    mov     r0, #0              @ fd = STDIN
    ldr     r1, =buf_opcion
    mov     r2, #8
    svc     0

    ldr     r4, =buf_opcion
    ldrb    r5, [r4]            @ r5 = primer caracter tecleado

    @ compara que apreto el usuario
    cmp     r5, #'a'
    beq     opcion_a
    cmp     r5, #'b'
    beq     opcion_b
    cmp     r5, #'c'
    beq     opcion_c
    cmp     r5, #'d'
    beq     opcion_d
    cmp     r5, #'e'
    beq     opcion_e
    cmp     r5, #'f'
    beq     opcion_f

    @ ninguna opcion coincidio: avisa y vuelve a mostrar el menu
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =msg_invalida
    ldr     r2, =len_invalida
    svc     0
    b       mostrar_menu

opcion_a:
    @ prepara el mensaje 'a' y salta a imprimirlo
    ldr     r1, =msg_a
    ldr     r2, =len_a
    b       escribir_y_preguntar

opcion_b:
    ldr     r1, =msg_b
    ldr     r2, =len_b
    b       escribir_y_preguntar

opcion_c:
    ldr     r1, =msg_c
    ldr     r2, =len_c
    b       escribir_y_preguntar

opcion_d:
    ldr     r1, =msg_d
    ldr     r2, =len_d
    b       escribir_y_preguntar

opcion_e:
    @ pedir que escriba e
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =prompt_propio
    ldr     r2, =len_propio
    svc     0

    @ leer lo que escribio
    mov     r7, #3
    mov     r0, #0
    ldr     r1, =buf_mensaje
    mov     r2, #256
    svc     0                   @ r0 = cantidad de bytes leidos (incluye '\n')

    @ prepara el mensaje leido para imprimirlo
    ldr     r1, =buf_mensaje
    mov     r2, r0              @ longitud = lo que devolvio read
    b       escribir_y_preguntar

opcion_f:
    @ dice chau y termina el programa de una vez
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =msg_despedida
    ldr     r2, =len_despedida
    svc     0
    b       terminar


@ escribir_y_preguntar: escribe el mensaje elegido (r1/r2 ya listos) y luego pregunta si se desea ver otro mensaje.

escribir_y_preguntar:
    @ imprime el mensaje escogido
    mov     r7, #4
    mov     r0, #1
    svc     0

    @ pregunta si el usuario quiere ver otro mensaje
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =prompt_continuar
    ldr     r2, =len_continuar
    svc     0

    @ lee la respuesta (1 = si, 2 = no)
    mov     r7, #3
    mov     r0, #0
    ldr     r1, =buf_continuar
    mov     r2, #8
    svc     0

    ldr     r4, =buf_continuar
    ldrb    r5, [r4]
    cmp     r5, #'1'
    beq     mostrar_menu        @ si respondio '1', vuelve a mostrar el menu

    @ cualquier otra respuesta: se despide y termina
    mov     r7, #4
    mov     r0, #1
    ldr     r1, =msg_despedida
    ldr     r2, =len_despedida
    svc     0

terminar:
    @ syscall exit(0)
    mov     r7, #1              @ syscall exit
    mov     r0, #0
    svc     0
