; ISR_KB.ASM -- ISR personalizado para IRQ1 (teclado)
; Compila: nasm -f bin ISR_KB.ASM -o ISR_KB.COM
;
; (1) guarda el vector original de INT 09h, (2) instala el ISR propio,
; (3) espera 5 pulsaciones y (4) restaura el handler original.
; Se imprime el vector antes, durante y despues para dejar evidencia de la
; instalacion y la restauracion.

[BITS 16]
[ORG 0x100]

section .data

MAX_KEYS    EQU 5           ; pulsaciones a atender antes de terminar
SCAN_BREAK  EQU 80h         ; bit 7 del scancode: tecla soltada (break)
PIC_CMD     EQU 20h         ; puerto de comandos del PIC maestro (EOI)
PIC_EOI     EQU 20h         ; comando End Of Interrupt no especifico
KBD_DATA    EQU 60h         ; puerto de datos del 8042

contador    DW 0            ; numero de teclas atendidas
old_isr     DD 0            ; almacena SEG:OFF del handler original

msg_orig    DB "Vector INT 09h original  : $"
msg_nuevo   DB "Vector INT 09h instalado : $"
msg_rest    DB "Vector INT 09h restaurado: $"
msg_pedir   DB "Presione 5 teclas...$"
msg_tecla   DB 0Dh, 0Ah, "Tecla detectada por ISR propio$"
msg_fin     DB 0Dh, 0Ah, "ISR restaurado. Fin del programa.", 0Dh, 0Ah, "$"
msg_crlf    DB 0Dh, 0Ah, "$"

section .text

start:
    ; ---- (1) Guardar vector original de INT 09h ----
    MOV  AX, 3509h              ; AH=35h: obtener vector INT 09h
    INT  21h                    ; ES:BX = direccion del handler actual
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    MOV  DX, msg_orig
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off       ; AX:BX

    ; ---- (2) Instalar ISR propio ----
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr             ; DS:DX = direccion del nuevo handler
    MOV  AX, 2509h              ; AH=25h: fijar vector INT 09h
    INT  21h
    POP  DS

    MOV  AX, 3509h              ; releer el vector para comprobar la instalacion
    INT  21h
    MOV  DX, msg_nuevo
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off

    MOV  DX, msg_pedir
    CALL imprimir_cadena

    STI                         ; asegurar interrupciones habilitadas

    ; ---- (3) Bucle activo hasta MAX_KEYS pulsaciones ----
.esperar:
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar

    ; ---- (4) Restaurar handler original ----
    CLI
    PUSH DS                     ; LDS modifica DS: se guarda y se repone
    LDS  DX, [old_isr]          ; DS:DX = handler original
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  DX, msg_fin
    CALL imprimir_cadena

    MOV  AX, 3509h              ; releer el vector para comprobar la restauracion
    INT  21h
    MOV  DX, msg_rest
    CALL imprimir_cadena
    MOV  AX, ES
    CALL imprimir_seg_off

    MOV  AH, 4Ch
    INT  21h

; ---- ISR propio ----
mi_isr:
    PUSH AX
    PUSH DX
    PUSH DS

    MOV  AX, CS                 ; DS apunta al segmento del programa
    MOV  DS, AX

    ; Leer y descartar el scancode del buffer del teclado
    IN   AL, KBD_DATA
    TEST AL, SCAN_BREAK         ; cada tecla genera make y break:
    JNZ  .eoi                   ; solo se cuenta el make

    ; Mostrar mensaje
    MOV  AH, 09h
    MOV  DX, msg_tecla
    INT  21h

    ; Incrementar contador
    INC  WORD [contador]

.eoi:
    ; Enviar EOI al PIC maestro (siempre, antes del IRET)
    MOV  AL, PIC_EOI
    OUT  PIC_CMD, AL

    POP  DS
    POP  DX
    POP  AX
    IRET                        ; retorna de la interrupcion

; ---- Subrutinas de impresion ----

; imprimir_cadena: DX = cadena terminada en '$'
imprimir_cadena:
    PUSH AX
    MOV  AH, 09h
    INT  21h
    POP  AX
    RET

; imprimir_seg_off: AX = segmento, BX = desplazamiento -> "SSSS:OOOO"
imprimir_seg_off:
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

; imprimir_hex_word: AX en 4 digitos hexadecimales
imprimir_hex_word:
    PUSH AX
    XCHG AL, AH
    CALL imprimir_hex_byte      ; byte alto
    XCHG AL, AH
    CALL imprimir_hex_byte      ; byte bajo
    POP  AX
    RET

; imprimir_hex_byte: AL en 2 digitos hexadecimales
imprimir_hex_byte:
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
