; TECL.ASM -- Lectura del estado del teclado 8042
; Compila: nasm -f bin TECL.ASM -o TECL.COM
;
; Puerto 60h = Data Port (ultimo scancode); puerto 64h = Status Register,
; bit 0 = OBF (Output Buffer Full: hay un dato listo para leer en 60h).

[BITS 16]                   ; programa .COM, CS=DS=ES=SS
[ORG 0x100]

DATA_PORT   EQU 60h         ; 8042: puerto de datos
STATUS_PORT EQU 64h         ; 8042: registro de estado
OBF_MASK    EQU 01h         ; bit 0 del estado: buffer de salida lleno

start:
    ; Correccion respecto a la guia: con IF=1 el handler de la BIOS (IRQ1)
    ; puede leer el puerto 60h antes que el bucle de polling y el programa
    ; veria el codigo de "soltar tecla" (por ejemplo 9Eh) en lugar del make
    ; (1Eh). CLI evita que la BIOS atienda IRQ1 mientras se hace el polling.
    CLI

    ; Esperar hasta que OBF=1 (dato disponible en el buffer de salida)
.poll:
    IN   AL, STATUS_PORT    ; leer registro de estado del 8042
    TEST AL, OBF_MASK       ; comprobar bit OBF
    JZ   .poll              ; si OBF=0, no hay dato listo -- repetir

    IN   AL, DATA_PORT      ; leer scancode del Data Port
    MOV  BL, AL             ; guardar scancode en BL

    ; Mostrar scancode en pantalla (conversion hex manual)
    MOV  AH, 02h            ; funcion DOS: imprimir caracter
    MOV  DL, BL
    SHR  DL, 4              ; nibble alto
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .printH
    ADD  DL, 07h            ; ajuste A-F
.printH:
    INT  21h

    MOV  DL, BL             ; nibble bajo
    AND  DL, 0Fh
    ADD  DL, 30h
    CMP  DL, 3Ah
    JL   .printL
    ADD  DL, 07h
.printL:
    INT  21h

    STI                     ; devolver las interrupciones a la BIOS

    MOV  AH, 02h            ; CR
    MOV  DL, 0Dh
    INT  21h
    MOV  DL, 0Ah            ; LF
    INT  21h

    MOV  AH, 4Ch            ; terminar programa
    INT  21h
