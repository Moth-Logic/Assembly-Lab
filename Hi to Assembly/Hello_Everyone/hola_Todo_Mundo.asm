;  Programa de menu de saludos en NASM para x86-64
;  Muestra un menú interactivo donde el usuario elige un saludo,
;  puede escribir su propio mensaje, y decide si quiere continuar.
;
;  Compilar y ejecutar:
;      nasm -f elf64 hola_Todo_Mundo.asm -o hola_Todo_Mundo.o
;      ld hola_Todo_Mundo.o -o hola_Todo_Mundo
;      ./hola_Todo_Mundo

DEFAULT ABS   ; Use absolute addressing (simpler for flat binary)

; === Sección de datos: todos los textos que el programa muestra ===
section .data
    ; --- Menú principal ---
    menu:           db 10, "Seleccione un mensaje:", 10  ; 10 = newline character
                    db "  a. Hola Mundo!!!", 10
                    db "  b. Feliz Dia del Amor y la Amistad!!!", 10
                    db "  c. Feliz Navidad!!!", 10
                    db "  d. Feliz Dia de la Independencia!!!", 10
                    db "  e. Otro (ingrese su propio mensaje)", 10
                    db "  f. Finalizar el programa", 10
                    db "Opcion: "
    len_menu:       equ $ - menu        ; Auto-calculate menu length in bytes

    ; --- Mensajes predefinidos (uno por cada opción del menú) ---
    msg_a:          db "Hola Mundo!!!", 10
    len_a:          equ $ - msg_a
    msg_b:          db "Feliz Dia del Amor y la Amistad!!!", 10
    len_b:          equ $ - msg_b
    msg_c:          db "Feliz Navidad!!!", 10
    len_c:          equ $ - msg_c
    msg_d:          db "Feliz Dia de la Independencia!!!", 10
    len_d:          equ $ - msg_d

    ; --- Texto para opción e (mensaje personalizado) ---
    prompt_propio:  db "Ingrese su propio mensaje: "
    len_propio:     equ $ - prompt_propio

    ; --- Pregunta "¿Quieres ver otro mensaje?" ---
    prompt_continuar: db 10, "Quieres ver otro mensaje?", 10
                        db "  1. Si", 10
                        db "  2. No, finalizar", 10
                        db "Opcion: "
    len_continuar:  equ $ - prompt_continuar

    ; --- Mensajes de error y despedida ---
    msg_invalida:   db "Opcion invalida, intente de nuevo.", 10
    len_invalida:   equ $ - msg_invalida
    msg_despedida:  db 10, "Chauuu!", 10
    len_despedida:  equ $ - msg_despedida

; === Sección BSS: buffers para datos que el usuario ingresa ===
section .bss
    buf_opcion:     resb 2      ; Buffer for menu choice (1 char + newline)
    buf_mensaje:    resb 256    ; Buffer for custom message (option e)
    buf_continuar:  resb 2      ; Buffer for "continue?" response

; === Sección de código ===
section .text
    global _start

; _start: the program entry point (equivalent to main() in C/Python)
_start:

; --- Show the menu and read user choice ---
mostrar_menu:
    ; Print the menu to stdout
    mov     rax, 1              ; syscall 1 = write
    mov     rdi, 1              ; file descriptor 1 = stdout
    mov     rsi, menu           ; pointer to the menu text
    mov     rdx, len_menu       ; number of bytes to write
    syscall

    ; Read user input from stdin
    mov     rax, 0              ; syscall 0 = read
    mov     rdi, 0              ; file descriptor 0 = stdin
    mov     rsi, buf_opcion     ; where to store the input
    mov     rdx, 8              ; max bytes to read
    syscall

    ; Compare the first character of input against each option
    movzx   rbx, byte [buf_opcion]   ; rbx = first character typed (zero-extended to 64-bit)

    cmp     bl, 'a'             ; Is it 'a'?
    je      opcion_a            ; If yes, jump to option_a
    cmp     bl, 'b'
    je      opcion_b
    cmp     bl, 'c'
    je      opcion_c
    cmp     bl, 'd'
    je      opcion_d
    cmp     bl, 'e'
    je      opcion_e
    cmp     bl, 'f'
    je      opcion_f

    ; No valid option matched: show error and loop back to menu
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, msg_invalida
    mov     rdx, len_invalida
    syscall
    jmp     mostrar_menu        ; Jump back to show the menu again

; --- Options a-d: print the pre-defined message, then ask to continue ---
opcion_a:
    mov     rsi, msg_a          ; Load pointer to "Hola Mundo!!!"
    mov     rdx, len_a          ; Load its length
    jmp     escribir_y_preguntar  ; Jump to the common print-and-ask code

opcion_b:
    mov     rsi, msg_b
    mov     rdx, len_b
    jmp     escribir_y_preguntar

opcion_c:
    mov     rsi, msg_c
    mov     rdx, len_c
    jmp     escribir_y_preguntar

opcion_d:
    mov     rsi, msg_d
    mov     rdx, len_d
    jmp     escribir_y_preguntar

; --- Option e: let the user type their own message ---
opcion_e:
    ; Ask the user to type a message
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, prompt_propio
    mov     rdx, len_propio
    syscall

    ; Read the user's custom message (up to 256 bytes)
    mov     rax, 0
    mov     rdi, 0
    mov     rsi, buf_mensaje
    mov     rdx, 256
    syscall                     ; rax = number of bytes actually read

    ; Print the message the user just typed
    mov     rsi, buf_mensaje
    mov     rdx, rax            ; Use the actual bytes read as the length
    jmp     escribir_y_preguntar

; --- Option f: say goodbye and exit ---
opcion_f:
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, msg_despedida
    mov     rdx, len_despedida
    syscall
    jmp     terminar            ; Jump to the exit code

; --- Common code: print message (rsi/rdx already set), then ask to continue ---
escribir_y_preguntar:
    ; Print the message (rsi and rdx are already loaded by the option code)
    mov     rax, 1
    mov     rdi, 1
    syscall

    ; Ask "¿Quieres ver otro mensaje?"
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, prompt_continuar
    mov     rdx, len_continuar
    syscall

    ; Read the response
    mov     rax, 0
    mov     rdi, 0
    mov     rsi, buf_continuar
    mov     rdx, 8
    syscall

    ; If user typed '1', go back to the menu. Otherwise, exit.
    cmp     byte [buf_continuar], '1'
    je      mostrar_menu        ; Jump back to menu if response is '1'

    ; Any other response: say goodbye and exit
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, msg_despedida
    mov     rdx, len_despedida
    syscall

; --- Exit the program ---
terminar:
    mov     rax, 60             ; syscall 60 = exit
    xor     rdi, rdi            ; exit code 0 (success)
    syscall
