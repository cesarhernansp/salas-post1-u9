; MULTI_ST.ASM -- Polling combinado de dos puertos de estado (teclado + LPT1)
; Compila: nasm -f bin MULTI_ST.ASM -o MULTI_ST.COM
; Solo teclado (demostracion): nasm -f bin -dIGNORAR_LPT MULTI_ST.ASM -o MULTI_K.COM
;
; Se aisla un bit de cada registro de estado, se normaliza a 0/1 y se
; combinan con OR: el bucle solo continua mientras NINGUN dispositivo este
; listo. Tras salir se examinan BL y BH por separado, porque el OR no dice
; cual de los dos dispositivos provoco la salida.

[BITS 16]
[ORG 0x100]

KBD_STATUS_PORT EQU 64h     ; 8042: registro de estado
KBD_OBF_MASK    EQU 01h     ; bit 0: OBF (dato listo)
LPT_STATUS_PORT EQU 0379h   ; LPT1: registro de estado (puerto > FFh: via DX)
LPT_READY_MASK  EQU 80h     ; bit 7: BUSY# (1 = lista)

start:
    CLI                     ; evita que la BIOS (IRQ1) consuma el scancode (ver TECL.ASM)

.poll:
    ; Bandera de teclado: bit 0 (OBF) del registro de estado 64h
    IN   AL, KBD_STATUS_PORT
    AND  AL, KBD_OBF_MASK
    MOV  BL, AL                 ; BL = bandera_teclado (0 o 1)

    ; Bandera de LPT1: bit 7 (listo) del registro de estado 0379h
    MOV  DX, LPT_STATUS_PORT
    IN   AL, DX
    AND  AL, LPT_READY_MASK
    SHR  AL, 7                  ; normaliza a 0 o 1
    MOV  BH, AL                 ; BH = bandera_lpt1 (0 o 1)

%ifdef IGNORAR_LPT
    XOR  BH, BH                 ; demostracion: se descarta la bandera de LPT1
%endif

    MOV  AL, BL
    OR   AL, BH                 ; AL = bandera_teclado OR bandera_lpt1
    JZ   .poll                  ; ningun dispositivo listo -> repetir

    STI

    ; Determinar cual(es) dispositivo(s) dispararon la condicion
    TEST BL, BL
    JZ   .solo_lpt1
    MOV  AH, 09h
    MOV  DX, msg_tecl
    INT  21h

.solo_lpt1:
    TEST BH, BH
    JZ   .fin
    MOV  AH, 09h
    MOV  DX, msg_lpt1
    INT  21h

.fin:
    MOV  AH, 4Ch
    INT  21h

msg_tecl DB "Teclado listo (OBF=1).", 0Dh, 0Ah, "$"
msg_lpt1 DB "LPT1 listo (BUSY#=1).", 0Dh, 0Ah, "$"
