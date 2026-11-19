; MASK_KB.ASM -- Enmascarar/desenmascarar IRQ1 con el PIC 8259A
; Compila: nasm -f bin MASK_KB.ASM -o MASK_KB.COM
;
; Enmascara IRQ1 (bit 1 del IMR, puerto 21h) durante ~3 segundos y luego
; restaura el IMR original. Antes de restaurarlo se consulta el bit OBF del
; 8042 (puerto 64h) para dejar evidencia de si una tecla quedo retenida.
; Los datos van DESPUES del codigo: en un .COM la ejecucion empieza en 0100h.

[BITS 16]
[ORG 0x100]

PIC_IMR      EQU 21h        ; IMR del PIC maestro
IRQ1_MASK    EQU 02h        ; bit 1 = IRQ1 (teclado)
KBD_STATUS   EQU 64h        ; 8042: registro de estado
OBF_MASK     EQU 01h        ; bit 0: OBF (hay scancode pendiente)
TICKS_ESPERA EQU 55         ; ~3 s a 18.2 ticks/s

start:
    ; Leer IMR actual y conservarlo
    IN   AL, PIC_IMR
    MOV  [imr_orig], AL

    MOV  DX, msg_imr_orig
    CALL imprimir_cadena
    MOV  AL, [imr_orig]
    CALL imprimir_hex_byte
    CALL imprimir_crlf

    ; Enmascarar IRQ1 (bit 1 del IMR)
    MOV  AL, [imr_orig]
    OR   AL, IRQ1_MASK
    OUT  PIC_IMR, AL

    IN   AL, PIC_IMR            ; releer para comprobar el cambio
    PUSH AX
    MOV  DX, msg_imr_mask
    CALL imprimir_cadena
    POP  AX
    CALL imprimir_hex_byte
    CALL imprimir_crlf

    MOV  DX, msg_mask
    CALL imprimir_cadena

    ; Esperar ~3 segundos con el contador de ticks de la BIOS (INT 1Ah)
    MOV  AH, 00h
    INT  1Ah                    ; CX:DX = ticks actuales
    MOV  BX, DX                 ; BX = tick inicial
.esperar:
    MOV  AH, 00h
    INT  1Ah
    SUB  DX, BX                 ; ticks transcurridos (seguro ante vuelta del contador)
    CMP  DX, TICKS_ESPERA
    JB   .esperar

    ; Evidencia: ¿quedo un scancode retenido en el 8042 mientras IRQ1 estaba enmascarado?
    IN   AL, KBD_STATUS
    TEST AL, OBF_MASK
    JZ   .sin_retenido
    MOV  DX, msg_retenido
    JMP  .informar
.sin_retenido:
    MOV  DX, msg_vacio
.informar:
    CALL imprimir_cadena

    ; Restaurar IMR original
    MOV  AL, [imr_orig]
    OUT  PIC_IMR, AL

    MOV  DX, msg_unmask
    CALL imprimir_cadena
    IN   AL, PIC_IMR
    CALL imprimir_hex_byte
    CALL imprimir_crlf

    MOV  AH, 4Ch
    INT  21h

; ---- Subrutinas ----
imprimir_cadena:                ; DX = cadena terminada en '$'
    PUSH AX
    MOV  AH, 09h
    INT  21h
    POP  AX
    RET

imprimir_crlf:
    PUSH DX
    MOV  DX, msg_crlf
    CALL imprimir_cadena
    POP  DX
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

; ---- Datos ----
imr_orig      DB 0

msg_imr_orig  DB "IMR original      (21h): $"
msg_imr_mask  DB "IMR enmascarado   (21h): $"
msg_mask      DB "IRQ1 enmascarado (teclado deshabilitado)...", 0Dh, 0Ah, "$"
msg_retenido  DB "OBF=1: hay un scancode retenido en el 8042 (la BIOS no lo atendio).", 0Dh, 0Ah, "$"
msg_vacio     DB "OBF=0: no llego ninguna tecla mientras IRQ1 estaba enmascarado.", 0Dh, 0Ah, "$"
msg_unmask    DB "IRQ1 restaurado. IMR actual (21h): $"
msg_crlf      DB 0Dh, 0Ah, "$"
