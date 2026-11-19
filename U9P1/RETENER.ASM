; RETENER.ASM -- Auxiliar de demostracion para MULTI_ST.ASM (no es parte de la guia)
; Compila: nasm -f bin RETENER.ASM -o RETENER.COM
;
; Enmascara IRQ1 en el IMR (puerto 21h) y espera ~8 segundos SIN volver a
; desenmascararlo. Una tecla presionada en ese lapso queda retenida en el
; buffer del 8042 (OBF=1) porque la BIOS no la atiende. Al ejecutar despues
; MULTI_ST, el bit OBF ya esta en 1 y las dos banderas coinciden.

[BITS 16]
[ORG 0x100]

IMR_PORT     EQU 21h        ; mascara de interrupciones del PIC maestro
IRQ1_MASK    EQU 02h        ; bit 1 = IRQ1 (teclado)
TICKS_ESPERA EQU 146        ; ~8 s (18.2 ticks/s)

start:
    IN   AL, IMR_PORT
    OR   AL, IRQ1_MASK
    OUT  IMR_PORT, AL           ; IRQ1 enmascarado (no se restaura)

    MOV  AH, 09h
    MOV  DX, msg_retener
    INT  21h

    MOV  AH, 00h
    INT  1Ah                    ; CX:DX = ticks actuales
    MOV  BX, DX                 ; BX = tick inicial
.esperar:
    MOV  AH, 00h
    INT  1Ah
    SUB  DX, BX                 ; ticks transcurridos
    CMP  DX, TICKS_ESPERA
    JB   .esperar

    MOV  AH, 4Ch
    INT  21h

msg_retener DB "IRQ1 enmascarado: presione una tecla (queda retenida en el 8042)...", 0Dh, 0Ah, "$"
