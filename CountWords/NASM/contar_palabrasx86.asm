;Julian SOlozarno y Abril Gonzalez Tarea COrta 07


global _start

section .data
    
    msg_resultado   db "Palabras: "
    msg_resultado_len equ $ - msg_resultado

    newline         db 10                            

    msg_prompt      db "Ingrese la ruta del archivo: "
    msg_prompt_len  equ $ - msg_prompt

    msg_uso         db "Error: no se indico la ruta del archivo.", 10
    msg_uso_len     equ $ - msg_uso

    msg_err_abrir   db "Error: no se pudo abrir el archivo.", 10
    msg_err_abrir_len equ $ - msg_err_abrir

    msg_err_leer    db "Error: fallo al leer el archivo.", 10
    msg_err_leer_len equ $ - msg_err_leer

    msg_err_largo   db "Error: la entrada excede el limite de 1024 caracteres.", 10
    msg_err_largo_len equ $ - msg_err_largo

section .bss
    
    buffer          resb 1025
    buffer_len      equ $ - buffer          
    numbuf          resb 21     ; aqui se escribe el resultado como texto
    pathbuf         resb 256    ; aqui se guarda el nombre del archivo
                                

section .text

contar_palabras:
    xor eax, eax                    ; words = 0
    xor edx, edx                    ; 

.siguiente:
    test rsi, rsi                   ; 
    jz .retorna                     ; 

    movzx ecx, byte [rdi]           ; tomar la letra actual
    inc rdi                         ; mover el puntero a la siguiente letra
    dec rsi                         ; ahora falta una letra menos

   
    cmp cl, 32                      ; 0 a 32
    jbe .separador
    cmp cl, 47                      ; 33 a 47
    jbe .separador
    cmp cl, 57                      ; 48 a 57 (numeros)
    jbe .parte_palabra
    cmp cl, 64                      ; 58 a 64
    jbe .separador
    cmp cl, 90                      ; 65 a 90 (mayusculas)
    jbe .parte_palabra
    cmp cl, 96                      ; 91 a 96
    jbe .separador
    cmp cl, 122                     ; 97 a 122 (minusculas)
    jbe .parte_palabra
    cmp cl, 126                     ; 123 a 126
    jbe .separador
    cmp cl, 127                     ; 127 (DEL)
    je .separador
                                   

.parte_palabra:
   
    test edx, edx
    jnz .siguiente                  

    inc eax                         ; No estaba
    mov edx, 1                      
    jmp .siguiente                  ; pasa a la siguiente letra

.separador:
    xor edx, edx                    
    jmp .siguiente                  ; pasar a la siguiente letra

.retorna:
    ret                             ;  el resultado queda en eax



;     r12 = cuantas letras se han leido
;     r13 = identificador del archivo abierto
;     r14 = donde empieza el numero ya convertido a texto
;     r15 = cuantos digitos tiene ese numero


_start:

    ; Obtener el nombre del archivo 
   
    mov rax, [rsp]                  ; rax = cuantos argumentos hay
    cmp rax, 2                      
    jl .pedir_ruta                  ;  preguntar el archivo
    mov rdi, [rsp + 16]             ;  usar el archivo escrito
    jmp .abrir

.pedir_ruta:
    ; Mostrar "Ingrese la ruta del archivo: "
    
    mov eax, 1                     
    mov edi, 1                     
    lea rsi, [rel msg_prompt]      
    mov edx, msg_prompt_len         
    syscall

    
    mov eax, 0                     
    mov edi, 0                    
    lea rsi, [rel pathbuf]         
    mov edx, 255                    
    syscall
    test rax, rax                   
    jle .err_uso                    ;mostrar error

    
    lea rdi, [rel pathbuf]         
    mov byte [rdi + rax], 0        
    mov rsi, rdi                    
    mov r8, rax   
    
    
.buscar_fin_linea:
    test r8, r8
    jz .ruta_lista                  
    mov al, [rsi]
    cmp al, 10                      ;  enter?
    je .cortar
    cmp al, 13                      ; enter?
    je .cortar
    inc rsi                         ; pasar a la siguiente letra
    dec r8
    jmp .buscar_fin_linea
    
.cortar:
    mov byte [rsi], 0               ; cambiar el Enter por un 0
    

.ruta_lista:
    cmp byte [rdi], 0               ; ruta vacia?
    je .err_uso                     

   
.abrir:                            
    mov eax, 2                      
    xor esi, esi                   
    xor edx, edx                  
    syscall
    test rax, rax                  
    js .err_abrir                 
    mov r13, rax                    ; guardar el identificador del archivo

    
.leer:
    mov rdx, buffer_len           
    sub rdx, r12                   
    jz .fin_lectura                 
    lea rsi, [rel buffer]
    add rsi, r12                  
    mov eax, 0                     
    mov rdi, r13                   
    syscall
    test rax, rax
    js .err_leer                    
    jz .fin_lectura                
    add r12, rax                   
    jmp .leer                       

.fin_lectura:
   
    mov eax, 3                   
    mov rdi, r13
    syscall

    
    cmp r12, buffer_len - 1
    ja .err_largo                   

    ; contar letras
    lea rdi, [rel buffer]           ; rdi = donde esta el texto
    mov rsi, r12                    ; rsi = cuantas letras tiene
    call contar_palabras           

   
    lea rdi, [rel numbuf]
    add rdi, 20                    
    mov ebx, 10                     
    xor r15d, r15d                 
    
    
.convertir:
    xor edx, edx                   
    div ebx                       
    add dl, '0'                  
    dec rdi                      
    mov [rdi], dl                   
    inc r15d                        
    test eax, eax
    jnz .convertir                
    mov r14, rdi               

   
    mov eax, 1                      
    mov edi, 1                     
    lea rsi, [rel msg_resultado]
    mov edx, msg_resultado_len     
    syscall


    mov eax, 1
    mov edi, 1
    mov rsi, r14                    
    mov edx, r15d                  
    syscall

   
    mov eax, 1
    mov edi, 1
    lea rsi, [rel newline]
    mov edx, 1
    syscall

   
    mov eax, 60                     
    xor edi, edi                   
    syscall


.err_uso:                         
    lea rsi, [rel msg_uso]
    mov edx, msg_uso_len            
    jmp .error
    
.err_abrir:                        
    lea rsi, [rel msg_err_abrir]
    mov edx, msg_err_abrir_len    
    jmp .error
    
.err_leer:                       
    lea rsi, [rel msg_err_leer]
    mov edx, msg_err_leer_len       
    jmp .error
    
.err_largo:                       
    lea rsi, [rel msg_err_largo]
    mov edx, msg_err_largo_len     
    
.error:
    mov eax, 1                   
    mov edi, 2                     
    syscall
    mov eax, 60                  
    mov edi, 1                      ; codigo 1 = hubo un error
    syscall

