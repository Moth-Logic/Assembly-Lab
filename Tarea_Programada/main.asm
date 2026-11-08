; ============================================================================
; main.asm - Punto de entrada y flujo principal
; ----------------------------------------------------------------------------
; QUE HACE:
;   Orquesta el programa: lee la linea de entrada, separa la expresion de las
;   asignaciones, tokeniza, evalua, imprime los pasos y por ultimo el
;   resultado (entero o en punto fijo con 2 decimales si FIXED2 esta activo).
;
; EXPORTA (global): _start
; IMPORTA (extern): io_read_input                     (io.asm)
;                   parser_find_expr_end, parser_parse_assignments,
;                   parser_begin_expression, parser_tokenize  (parser.asm)
;                   eval_expression                     (evaluator.asm)
;                   display_print_steps, print_number, print_fixed2
;                                                       (display.asm)
;                   report_error                        (errors.asm)
;
; Convencion System V AMD64 en todas las llamadas internas.
; ============================================================================
BITS 64
DEFAULT REL

SYS_EXIT equ 60

ERR_INVALID equ 1

extern io_read_input
extern parser_find_expr_end
extern parser_parse_assignments
extern parser_begin_expression
extern parser_tokenize
extern eval_expression
extern display_print_steps
extern print_number
extern print_fixed2
extern report_error

global _start

section .text
_start:
    call io_read_input              ; rax = bytes leidos
    test rax, rax
    jz .empty

    call parser_find_expr_end       ; expr_limit = fin de la expresion
    call parser_parse_assignments   ; guarda "x=50, y=5, ..."
    call parser_begin_expression
    call parser_tokenize            ; tokens + validacion sintactica

    call eval_expression            ; rax:rdx = resultado
    mov rbx, rax                    ; lo preservamos para imprimirlo despues
    mov rbp, rdx
    call display_print_steps        ; Extra 4: estados intermedios

    mov rax, rbx
    mov rdx, rbp
%ifdef FIXED2
    mov rdi, rax                    ; Extra 5: resultado escalado x100
    call print_fixed2
%else
    call print_number
%endif

    mov eax, SYS_EXIT
    xor edi, edi
    syscall
.empty:
    mov edi, ERR_INVALID
    call report_error

section .note.GNU-stack noalloc noexec nowrite progbits
