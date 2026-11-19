; LPT_1.ASM -- Envio de un caracter al puerto paralelo LPT1 (protocolo centronics)
; Compila: nasm -f bin LPT_1.ASM -o LPT_1.COM
;
; Nota: la guia lo llama LPT1.ASM, pero "LPT1" es un nombre de dispositivo
; reservado en DOS (y en Windows): DOS no deja ensamblar ni ejecutar LPT1.*.
; Por eso el archivo se llama LPT_1.
; Registros: 0378h = datos (D0-D7), 0379h = estado, 037Ah = control.
; Los puertos > FFh solo se acceden con el numero de puerto en DX
; (IN AL, DX / OUT DX, AL); la forma con inmediato solo llega hasta FFh.

[BITS 16]
[ORG 0x100]

DATA_PORT    EQU 0378h      ; registro de datos
STATUS_PORT  EQU 0379h      ; registro de estado
CTRL_PORT    EQU 037Ah      ; registro de control
BUSY_MASK    EQU 80h        ; estado bit 7: BUSY# (1 = impresora lista)
ACK_MASK     EQU 40h        ; estado bit 6: ACK# (0 = peticion reconocida)
STROBE_MASK  EQU 01h        ; control bit 0: STROBE
CARACTER     EQU 41h        ; caracter a enviar: "A"
ACK_RETRY    EQU 0FFFh      ; reintentos maximos esperando ACK

start:
    ; (1) Esperar BUSY=1 (impresora lista)
.wait_ready:
    MOV  DX, STATUS_PORT
    IN   AL, DX
    TEST AL, BUSY_MASK
    JZ   .wait_ready
    MOV  BL, AL                 ; BL = registro de estado observado

    MOV  AH, 09h
    MOV  DX, msg_estado
    INT  21h
    MOV  AL, BL
    CALL imprimir_hex_byte
    MOV  AH, 09h
    MOV  DX, msg_crlf
    INT  21h

    ; (2) Colocar el dato en el bus de datos
    MOV  DX, DATA_PORT
    MOV  AL, CARACTER
    OUT  DX, AL

    ; (3) Pulso STROBE (se baja el bit 0 y luego se vuelve a subir)
    MOV  DX, CTRL_PORT
    IN   AL, DX
    AND  AL, 0FEh               ; STROBE=0
    OUT  DX, AL

    MOV  CX, 0Fh                ; retardo minimo (~1 us en DOSBox)
.delay:
    LOOP .delay

    OR   AL, STROBE_MASK        ; STROBE=1
    OUT  DX, AL

    MOV  AH, 09h
    MOV  DX, msg_enviado
    INT  21h

    ; (4) Esperar ACK (bit 6 en bajo), con limite para no bloquear
    MOV  CX, ACK_RETRY
.wait_ack:
    MOV  DX, STATUS_PORT
    IN   AL, DX
    TEST AL, ACK_MASK
    JZ   .ack_recibido
    LOOP .wait_ack

    MOV  AH, 09h
    MOV  DX, msg_sin_ack
    INT  21h
    JMP  .fin

.ack_recibido:
    MOV  AH, 09h
    MOV  DX, msg_ack
    INT  21h

.fin:
    MOV  AH, 4Ch
    INT  21h

; ---- Subrutina: imprime AL como dos digitos hexadecimales ----
imprimir_hex_byte:
    PUSH AX
    PUSH DX
    MOV  DH, AL
    MOV  DL, DH
    SHR  DL, 4                  ; nibble alto
    CALL .nibble
    MOV  DL, DH
    AND  DL, 0Fh                ; nibble bajo
    CALL .nibble
    POP  DX
    POP  AX
    RET
.nibble:
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .imprimir
    ADD  DL, 07h                ; ajuste A-F
.imprimir:
    MOV  AH, 02h
    INT  21h
    RET

msg_estado  DB 'Estado de 0379h (BUSY# listo): $'
msg_crlf    DB 0Dh, 0Ah, '$'
msg_enviado DB "Caracter 'A' (41h) escrito en 0378h y pulso STROBE emitido.", 0Dh, 0Ah, '$'
msg_ack     DB 'ACK recibido (bit 6 en bajo).', 0Dh, 0Ah, '$'
msg_sin_ack DB 'Sin ACK: no hay periferico conectado (bit 6 queda en alto).', 0Dh, 0Ah, '$'
