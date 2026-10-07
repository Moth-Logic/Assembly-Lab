;  Programa "Hola Mundo" en NASM para x86-64 (Intel/AMD)
;  Este es el equivalente en ensamblador de "print('Hola Mundo')" en Python.
;
;  Para compilar y ejecutar:
;      nasm -f elf64 hola_mundo.asm -o hola_mundo.o
;      ld hola_mundo.o -o hola_mundo
;      ./hola_mundo

; === Sección de datos: variables y constantes que nuestro programa usa ===
section .data
    mensaje:    db "Hola Mundo", 10      ; El texto a imprimir. 10 = newline (\n en C/Python)
    long_msg:   equ $ - mensaje          ; 'equ' calcula la longitud automáticamente:
                                         ; $ = dirección actual, mensaje = dirección del texto
                                         ; Restarlas da el número exacto de bytes

; === Sección de código: las instrucciones que el procesador ejecuta ===
section .text
    global _start                        ; '_start' es el punto de entrada (como main() en C/Python)

; _start: el equivalente de main() — aquí empieza la ejecución
_start:
    ; --- Imprimir el mensaje (syscall write) ---
    ; En Linux, los programas le piden al "kernel" que haga el trabajo pesado
    ; (como imprimir) usando syscalls. Es como llamar a una función del sistema.
    mov     rax, 1              ; rax = número de syscall: 1 = write
    mov     rdi, 1              ; rdi = file descriptor: 1 = stdout (la pantalla)
    mov     rsi, mensaje        ; rsi = puntero al mensaje (dirección en memoria)
    mov     rdx, long_msg       ; rdx = cuántos bytes imprimir
    syscall                     ; ¡ACTIONS! El kernel ejecuta write(1, mensaje, long_msg)

    ; --- Terminar el programa (syscall exit) ---
    mov     rax, 60             ; rax = 60 = exit syscall
    xor     rdi, rdi            ; rdi = 0 (código de salida normal)
                                 ; 'xor rdi, rdi' es la forma más eficiente de poner rdi = 0
                                 ; porque el procesador lo optimiza mejor que 'mov rdi, 0'
    syscall                     ; El kernel termina el proceso con código 0 (éxito)
