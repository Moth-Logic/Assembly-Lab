; Letter Swap: toggle the case of every letter in a string.
; 'A' (0x41) and 'a' (0x61) differ by exactly ONE bit: bit 5 (0x20).
;   'A' = 0100 0001
;   'a' = 0110 0001
; So we can use XOR with 0x20 to flip that bit — it toggles between
; uppercase and lowercase in a single instruction, regardless of
; which case the letter currently is.
;
; Compiling and running:
;      nasm -f elf64 letter_swap.asm -o letter_swap.o
;      ld letter_swap.o -o letter_swap
;      ./letter_swap

CASE_BIT   equ 0x20        ; The bit that distinguishes uppercase from lowercase

section .data
    prompt:      db "Insert your message: "
    prompt_len:  equ $ - prompt

section .bss
    buffer:      resb 101      ; 100 characters + the newline from pressing Enter

section .text
    global _start

_start:
    ; --- Print the prompt asking for user input ---
    mov     rax, 1              ; syscall 1 = write
    mov     rdi, 1              ; stdout
    mov     rsi, prompt
    mov     rdx, prompt_len
    syscall

    ; --- Read the user's message from stdin ---
    mov     rax, 0              ; syscall 0 = read
    mov     rdi, 0              ; stdin
    mov     rsi, buffer
    mov     rdx, 101            ; max bytes to read
    syscall                     ; rax = actual bytes read

    mov     rcx, rax            ; Save the real length (we need it for printing later)
    xor     rbx, rbx            ; rbx = current character index, starts at 0

.convert_loop:
; --- Main loop: process each character in the buffer ---
    cmp     rbx, rcx            ; Have we processed all characters?
    jge     .done_convert       ; If yes, exit the loop

    movzx   eax, byte [buffer + rbx]   ; Load current character into AL (zero-extended)

    ; --- Check if it's an UPPERCASE letter (0x41 = 'A' to 0x5A = 'Z') ---
    cmp     al, 0x41            ; Is it less than 'A'?
    jl      .check_lower        ; If yes, it's not uppercase — check lowercase
    cmp     al, 0x5A            ; Is it greater than 'Z'?
    jg      .check_lower        ; If yes, not uppercase either

    ; It IS uppercase! Flip bit 5 to make it lowercase.
    xor     al, CASE_BIT        ; XOR with 0x20: 'A'->'a', 'B'->'b', etc.
    mov     [buffer + rbx], al  ; Write the modified character back to the buffer
    jmp     .next_char          ; Done with this character, move to the next

.check_lower:
    ; --- Check if it's a lowercase letter (0x61 = 'a' to 0x7A = 'z') ---
    cmp     al, 0x61            ; Is it less than 'a'?
    jl      .next_char          ; Not a letter — leave it unchanged
    cmp     al, 0x7A            ; Is it greater than 'z'?
    jg      .next_char          ; Not a letter — leave it unchanged

    ; It IS lowercase! Flip bit 5 to make it uppercase.
    ; The SAME XOR works in both directions — that's the beauty of XOR.
    xor     al, CASE_BIT        ; 'a'->'A', 'b'->'B', etc.
    mov     [buffer + rbx], al  ; Write back to buffer

.next_char:
    inc     rbx                 ; Move to the next character
    jmp     .convert_loop       ; Repeat

.done_convert:
    ; --- Print the modified buffer (case-swapped) ---
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, buffer
    mov     rdx, rcx            ; Use the REAL length we saved earlier
    syscall

    ; --- Exit ---
    mov     rax, 60
    xor     rdi, rdi
    syscall