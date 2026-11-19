; POLL_T.ASM -- Polling con timeout para el puerto de teclado
; Compila: nasm -f bin POLL_T.ASM -o POLL_T.COM
; Otro limite:  nasm -f bin -dMAX_RETRY=0FFFFh POLL_T.ASM -o POLL_T.COM
;
; A diferencia de TECL.ASM, el bucle de espera esta acotado por un contador
; de reintentos: si CX llega a 0 sin que OBF se active, se informa un timeout.

[BITS 16]
[ORG 0x100]

DATA_PORT   EQU 60h         ; 8042: puerto de datos
STATUS_PORT EQU 64h         ; 8042: registro de estado
OBF_MASK    EQU 01h         ; bit 0 del estado: buffer de salida lleno

%ifndef MAX_RETRY
MAX_RETRY   EQU 0005h       ; numero maximo de reintentos (pequeno: fuerza el timeout)
%endif

start:
    MOV  CX, MAX_RETRY      ; contador de reintentos

.poll:                      ; LOOP decrementa CX y salta mientras CX != 0
    IN   AL, STATUS_PORT
    TEST AL, OBF_MASK
    JNZ  .dato_listo
    LOOP .poll

    ; Timeout: CX llego a 0 sin dato
    MOV  AH, 09h
    MOV  DX, msg_timeout
    INT  21h
    JMP  .fin

.dato_listo:                ; mostrar el byte leido (impresion directa)
    IN   AL, DATA_PORT
    MOV  AH, 02h
    MOV  DL, AL
    INT  21h

.fin:
    MOV  AH, 4Ch
    INT  21h

msg_timeout DB 'Timeout: sin respuesta del dispositivo', 0Dh, 0Ah, '$'
