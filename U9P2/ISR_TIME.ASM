; ISR_TIME.ASM -- Mide el intervalo entre interrupciones de teclado
; leyendo el contador de ticks del sistema en 0040h:006Ch
; Compila: nasm -f bin ISR_TIME.ASM -o ISR_TIME.COM
;
; El BIOS incrementa ese contador de 32 bits unas 18.2 veces por segundo
; (IRQ0). El ISR de IRQ1 lee su palabra baja, la resta de la lectura anterior
; y obtiene los ticks transcurridos entre dos pulsaciones, sin usar INT 1Ah.

[BITS 16]
[ORG 0x100]

section .data

MAX_KEYS      EQU 5         ; pulsaciones a medir antes de terminar
SCAN_BREAK    EQU 80h       ; bit 7 del scancode: tecla soltada (break)
KBD_DATA      EQU 60h       ; puerto de datos del 8042
PIC_CMD       EQU 20h       ; puerto de comandos del PIC maestro
PIC_EOI       EQU 20h       ; comando End Of Interrupt no especifico
BIOS_DATA_SEG EQU 0040h     ; segmento del area de datos de la BIOS
TICK_COUNT    EQU 006Ch     ; desplazamiento del contador de ticks (palabra baja)

old_isr     DD 0            ; SEG:OFF del handler original de INT 09h
ticks_prev  DW 0            ; ultima lectura del contador de ticks (palabra baja)
contador    DW 0            ; interrupciones atendidas

msg_inicio  DB "Presione 5 teclas, con pausas distintas entre ellas.", 0Dh, 0Ah, "$"
msg_ticks   DB 0Dh, 0Ah, "Ticks desde la interrupcion anterior: $"
msg_fin     DB 0Dh, 0Ah, "ISR_TIME restaurado. Fin del programa.", 0Dh, 0Ah, "$"

section .text

start:
    ; Guardar vector original de INT 09h
    MOV  AX, 3509h
    INT  21h
    MOV  [old_isr], BX
    MOV  [old_isr+2], ES

    ; Inicializar ticks_prev con la lectura actual del contador (0040h:006Ch)
    PUSH ES
    MOV  AX, BIOS_DATA_SEG
    MOV  ES, AX
    MOV  AX, [ES:TICK_COUNT]    ; palabra baja del contador de ticks BIOS
    MOV  [ticks_prev], AX
    POP  ES

    ; Instalar ISR propio
    PUSH DS
    MOV  AX, CS
    MOV  DS, AX
    MOV  DX, mi_isr
    MOV  AX, 2509h
    INT  21h
    POP  DS

    MOV  AH, 09h
    MOV  DX, msg_inicio
    INT  21h

    STI

.esperar:
    MOV  AX, [contador]
    CMP  AX, MAX_KEYS
    JL   .esperar

    ; Restaurar handler original
    CLI
    PUSH DS                     ; LDS modifica DS: se guarda y se repone
    LDS  DX, [old_isr]
    MOV  AX, 2509h
    INT  21h
    POP  DS
    STI

    MOV  AH, 09h
    MOV  DX, msg_fin
    INT  21h
    MOV  AH, 4Ch
    INT  21h

; ---- ISR propio con medicion de intervalo ----
mi_isr:
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH DS
    PUSH ES

    MOV  AX, CS
    MOV  DS, AX

    IN   AL, KBD_DATA           ; leer y descartar el scancode (libera el 8042)
    TEST AL, SCAN_BREAK         ; cada tecla genera make y break:
    JNZ  .solo_eoi              ; solo se mide el make

    ; Leer el contador de ticks actual (0040h:006Ch, palabra baja)
    MOV  AX, BIOS_DATA_SEG
    MOV  ES, AX
    MOV  AX, [ES:TICK_COUNT]
    MOV  BX, AX
    SUB  BX, [ticks_prev]       ; BX = ticks transcurridos desde la interrupcion anterior
    MOV  [ticks_prev], AX

    ; Enviar EOI antes de la impresion (ver Decision Tecnica de esta parte)
    MOV  AL, PIC_EOI
    OUT  PIC_CMD, AL

    ; Imprimir mensaje + numero de ticks (BX)
    MOV  AH, 09h
    MOV  DX, msg_ticks
    INT  21h
    MOV  AX, BX
    CALL imprimir_decimal

    INC  WORD [contador]
    JMP  .salir

.solo_eoi:
    MOV  AL, PIC_EOI            ; el break tambien debe confirmarse al PIC
    OUT  PIC_CMD, AL

.salir:
    POP  ES
    POP  DS
    POP  DX
    POP  BX
    POP  AX
    IRET

; ---- Subrutina: imprime AX en decimal (sin signo) ----
imprimir_decimal:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  BX, 10
    XOR  CX, CX                 ; CX = numero de digitos
.dividir:
    XOR  DX, DX
    DIV  BX                     ; AX = cociente, DX = digito
    PUSH DX
    INC  CX
    TEST AX, AX
    JNZ  .dividir
.imprimir:
    POP  DX
    ADD  DL, 30h
    MOV  AH, 02h
    INT  21h
    LOOP .imprimir

    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
