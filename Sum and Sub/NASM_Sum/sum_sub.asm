; Sum and Subtract: read two numbers, validate they're digits only,
; and print their sum and difference in decimal.
; If the input isn't numeric, the program aborts with an error.
;
; This demonstrates: function calls in assembly, input parsing,
; signed number handling, and building output strings backwards.

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
    MAX_IN    equ 22      ; 20 digits + newline + margin
    MAX_OUT   equ 24      ; 20 digits + sign + newline + null terminator

section .bss
    buf1      resb MAX_IN
    buf2      resb MAX_IN
    outbuf    resb MAX_OUT

section .text
    global _start

; Print a null-terminated string to stdout.
; Input: rdi = pointer to the string.
; This function first counts the string length, then calls write().
print_string:
    xor     rcx, rcx            ; rcx = string length counter, start at 0
.len:
    cmp     byte [rdi + rcx], 0 ; Have we reached the null terminator (0)?
    je      .go                 ; If yes, we know the length
    inc     rcx                 ; Otherwise, count this character
    jmp     .len                ; Keep checking
.go:
    mov     rsi, rdi            ; rsi = pointer to the string (for write syscall)
    mov     rdi, STDOUT         ; rdi = file descriptor (stdout = 1)
    mov     rdx, rcx            ; rdx = number of bytes to write
    mov     rax, SYS_WRITE      ; rax = syscall number (write = 1)
    syscall
    ret

; Read a number from stdin, parse it, and return it as an integer.
; Input: rdi = prompt string pointer, rsi = buffer pointer.
; Output: rax = parsed integer, carry flag set on error.
; We use callee-saved registers (r12, r13) so they survive across function calls.
read_number:
    push    r12                 ; Save r12 (we'll use it to hold the buffer pointer)
    mov     r12, rsi            ; r12 = buffer pointer (survives the print_string call)

    call    print_string        ; Show the prompt ("Ingrese primer numero: ")

    ; Read user input from stdin into the buffer
    mov     rax, SYS_READ
    mov     rdi, STDIN
    mov     rsi, r12
    mov     rdx, MAX_IN - 1
    syscall                     ; rax = bytes read (includes the newline)

    dec     rax                 ; Subtract 1 to discard the trailing newline
    jle     .error              ; If no characters left, input was empty — error

    ; --- Parse the string into an integer ---
    ; Algorithm: result = result * 10 + (char - '0') for each digit
    ; Example: "123" → 0*10+1=1, 1*10+2=12, 12*10+3=123
    xor     r8, r8              ; r8 = accumulated number (starts at 0)
    xor     r9, r9              ; r9 = current character index
.parse:
    cmp     r9, rax             ; Have we processed all characters?
    jge     .ok                 ; If yes, parsing is complete
    movzx   r10, byte [r12 + r9]  ; Load current character into r10
    cmp     r10, '0'            ; Is it less than '0'?
    jl      .error              ; If yes, not a digit — error
    cmp     r10, '9'            ; Is it greater than '9'?
    jg      .error              ; If yes, not a digit — error
    sub     r10, '0'            ; Convert ASCII to actual digit (e.g., '3' → 3)
    imul    r8, r8, 10          ; Shift existing number left by one decimal place
    add     r8, r10             ; Add the new digit
    inc     r9                  ; Move to next character
    jmp     .parse
.ok:
    mov     rax, r8             ; Return the parsed number in rax
    pop     r12                 ; Restore r12
    clc                         ; Clear carry flag = success
    ret
.error:
    pop     r12                 ; Restore r12
    stc                         ; Set carry flag = error
    ret

; Print a number in decimal (with sign if negative).
; Input: rdi = pointer to a message string, rax = the 64-bit number to print.
; The number is converted to a string by repeatedly dividing by 10,
; building the digits backwards in the output buffer, then printing.
print_number:
    push    r12
    mov     r12, rax            ; Save the number (print_string will overwrite rax)

    call    print_string        ; Print the message first (e.g., "La suma es: ")

    ; Build the number string BACKWARDS in outbuf, starting from the end.
    lea     rsi, [outbuf + MAX_OUT - 1]
    mov     byte [rsi], 0       ; Null-terminate the string at the end

    mov     rax, r12            ; Restore the number
    xor     r8, r8              ; r8 = 1 if negative, 0 if positive
    cmp     rax, 0
    jge     .conv
    mov     r8, 1               ; Mark as negative
    neg     rax                 ; Work with the absolute value from now on

.conv:
    mov     rbx, 10             ; Divisor for decimal conversion
.loop:
    xor     rdx, rdx            ; Clear rdx (required before div)
    div     rbx                 ; rax = rax / 10, rdx = remainder (the next digit)
    add     dl, '0'             ; Convert digit to ASCII ('0' + digit)
    dec     rsi                 ; Move buffer pointer backwards
    mov     [rsi], dl           ; Store the digit character
    test    rax, rax            ; Are there more digits?
    jnz     .loop               ; If yes, keep dividing

    ; If the number was negative, prepend the '-' sign.
    test    r8, r8
    jz      .print
    dec     rsi
    mov     byte [rsi], '-'     ; Place the minus sign before the digits

.print:
    ; Calculate the actual string length (MAX_OUT - 1 - rsi).
    lea     rdx, [outbuf + MAX_OUT - 1]
    sub     rdx, rsi            ; rdx = length of the number string
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    syscall

    ; Print a newline character.
    mov     byte [outbuf], 10   ; Reuse outbuf[0] for the newline
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [outbuf]
    mov     rdx, 1
    syscall

    pop     r12
    ret

_start:
    ; --- Read the first number ---
    mov     rdi, msg_num1       ; Prompt message
    mov     rsi, buf1           ; Buffer to store input
    call    read_number         ; Parse the input into an integer
    jc      .bad                ; If carry flag is set, input was invalid
    mov     r12, rax            ; Save first number in r12 (callee-saved register)

    ; --- Read the second number ---
    mov     rdi, msg_num2
    mov     rsi, buf2
    call    read_number
    jc      .bad                ; Invalid input? Jump to error handler
    mov     r13, rax            ; Save second number in r13

    ; --- Calculate and print the SUM ---
    mov     rax, r12            ; Load first number
    add     rax, r13            ; rax = first + second
    mov     rdi, msg_sum        ; "La suma es: "
    call    print_number        ; Print the result

    ; --- Calculate and print the DIFFERENCE ---
    mov     rax, r12            ; Load first number
    sub     rax, r13            ; rax = first - second (may be negative)
    mov     rdi, msg_sub        ; "La resta es: "
    call    print_number        ; Print the result (print_number handles negatives)

    ; --- Exit successfully ---
    mov     rax, SYS_EXIT
    xor     rdi, rdi            ; Exit code 0 = success
    syscall

; --- Error handler: print error message and exit with code 1 ---
.bad:
    mov     rdi, msg_error
    call    print_string        ; Print "Error: Ingrese solo numeros."
    mov     rax, SYS_EXIT
    mov     rdi, 1              ; Exit code 1 = error
    syscall
