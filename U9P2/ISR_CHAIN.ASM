; ISR_CHAIN.ASM -- ISR de IRQ1 con encadenamiento al handler original
; Compila: nasm -f bin ISR_CHAIN.ASM -o ISR_CHAIN.COM
;
; Derivado de ISR_KB.ASM. En lugar de reemplazar el handler de la BIOS, el ISR
; registra la tecla en su propio contador y luego llama al handler original
; con PUSHF + CALL FAR (simula una INT). Como el handler original lee el
; scancode, lo coloca en el buffer del teclado y envia el EOI al PIC, este ISR
; NO envia EOI: seria un EOI doble.

[BITS 16]
[ORG 0x100]

section .data

MAX_KEYS    EQU 5           ; pulsaciones a registrar antes de terminar
SCAN_BREAK  EQU 80h         ; bit 7 del scancode: tecla soltada (break)
KBD_DATA    EQU 60h         ; puerto de datos del 8042

contador    DW 0            ; teclas registradas por el ISR propio
ultimo_scan DB 0            ; ultimo scancode make visto por el ISR
old_isr     DD 0            ; SEG:OFF del handler original de INT 09h

msg_orig    DB "Vector INT 09h original  : $"
msg_nuevo   DB "Vector INT 09h encadenado: $"
msg_rest    DB "Vector INT 09h restaurado: $"
msg_pedir   DB "Escriba 5 teclas (el eco de DOS debe seguir funcionando): $"
msg_cuenta  DB 0Dh, 0Ah, "Teclas registradas por el ISR propio: $"
msg_scan    DB 0Dh, 0Ah, "Ultimo scancode registrado (make)   : $"
msg_fin     DB "ISR restaurado. Fin del programa.", 0Dh, 0Ah, "$"
msg_crlf    DB 0Dh, 0Ah, "$"

section .text

start:
    ; ---- Guardar vector original de INT 09h ----
    MOV  AX, 3509h
    INT  21h                    ; ES:BX = handler actual
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    MOV  DX, msg_orig
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off

    ; ---- Instalar el ISR encadenado ----
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr_chain
    MOV  AX, 2509h
    INT  21h
    POP  DS

    MOV  AX, 3509h              ; releer el vector para comprobar
    INT  21h
    MOV  DX, msg_nuevo
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off

    MOV  DX, msg_pedir
    CALL imprimir_cadena
    STI

    ; ---- Bucle: eco de DOS hasta registrar MAX_KEYS teclas ----
.esperar:
    CALL eco_tecla              ; lee del buffer de la BIOS y repite en pantalla
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar

    ; Vaciar el buffer: el ultimo caracter ya esta en la BIOS gracias al encadenamiento
.vaciar:
    CALL eco_tecla
    JNZ  .vaciar                ; eco_tecla devuelve ZF=0 si imprimio algo

    ; ---- Restaurar handler original ----
    CLI
    PUSH DS
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  DX, msg_cuenta
    CALL imprimir_cadena
    MOV  AX, [contador]
    ADD  AL, 30h                ; contador < 10: un solo digito
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h

    MOV  DX, msg_scan
    CALL imprimir_cadena
    MOV  AL, [ultimo_scan]
    CALL imprimir_hex_byte
    MOV  DX, msg_crlf
    CALL imprimir_cadena

    MOV  DX, msg_fin
    CALL imprimir_cadena
    MOV  AX, 3509h
    INT  21h
    MOV  DX, msg_rest
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off

    MOV  AH, 4Ch
    INT  21h

; ---- ISR propio con encadenamiento ----
mi_isr_chain:
    PUSH AX
    PUSH DS

    MOV  AX, CS
    MOV  DS, AX

    IN   AL, KBD_DATA           ; solo se LEE el scancode: el original lo vuelve a leer
    TEST AL, SCAN_BREAK         ; ignorar los codigos de tecla soltada
    JNZ  .encadenar
    MOV  [ultimo_scan], AL
    INC  WORD [contador]        ; registro propio de la tecla

.encadenar:
    POP  DS
    POP  AX
    ; Encadenar con el handler original (simular INT: PUSHF + far CALL).
    ; El original termina con IRET, que retorna aqui; el EOI lo envia el original.
    PUSHF
    CALL FAR [CS:old_isr]       ; old_isr contiene SEG:OFF del handler original
    IRET

; ---- Subrutinas ----

; eco_tecla: lee un caracter sin esperar (INT 21h AH=06h) y lo imprime.
; Salida: ZF=0 si imprimio un caracter, ZF=1 si no habia ninguno.
eco_tecla:
    PUSH AX
    PUSH DX
    MOV  AH, 06h
    MOV  DL, 0FFh
    INT  21h
    JZ   .nada                  ; ZF=1: buffer vacio
    MOV  DL, AL
    MOV  AH, 02h
    INT  21h                    ; eco del caracter
    XOR  AX, AX
    INC  AX                     ; ZF=0
.nada:
    POP  DX
    POP  AX                     ; POP no altera ZF
    RET

imprimir_cadena:                ; DX = cadena terminada en '$'
    PUSH AX
    MOV  AH, 09h
    INT  21h
    POP  AX
    RET

imprimir_seg_off:               ; AX = segmento, BX = desplazamiento -> "SSSS:OOOO"
    PUSH AX
    PUSH BX
    PUSH DX
    CALL imprimir_hex_word
    MOV  AH, 02h
    MOV  DL, ':'
    INT  21h
    MOV  AX, BX
    CALL imprimir_hex_word
    MOV  DX, msg_crlf
    CALL imprimir_cadena
    POP  DX
    POP  BX
    POP  AX
    RET

imprimir_hex_word:              ; AX en 4 digitos hexadecimales
    PUSH AX
    XCHG AL, AH
    CALL imprimir_hex_byte
    XCHG AL, AH
    CALL imprimir_hex_byte
    POP  AX
    RET

imprimir_hex_byte:              ; AL en 2 digitos hexadecimales
    PUSH AX
    PUSH DX
    MOV  DH, AL
    MOV  DL, DH
    SHR  DL, 4
    CALL .nibble
    MOV  DL, DH
    AND  DL, 0Fh
    CALL .nibble
    POP  DX
    POP  AX
    RET
.nibble:
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .imprimir
    ADD  DL, 07h
.imprimir:
    MOV  AH, 02h
    INT  21h
    RET
