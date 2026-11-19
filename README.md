# salas-post1-u9 — Entrada y Salida avanzados: puertos, polling e interrupciones

**Autor:** César Hernán Salas Peñaranda  
**Curso:** Arquitectura de Computadores — Unidad 9, post-contenido (laboratorio en dos partes)  
**Repositorio único:** `salas-post1-u9`

Este repositorio reúne las dos partes del laboratorio de entrada y salida avanzados con NASM sobre DOSBox. La Parte 1 trabaja el acceso directo a puertos con `IN`/`OUT`, el polling y el polling combinado de dos puertos de estado. La Parte 2 trabaja una rutina de servicio de interrupción (ISR) para IRQ1, el enmascaramiento con el IMR del PIC 8259A, el encadenamiento de ISR y la medición de ticks en `0040h:006Ch`.

## Entorno de trabajo

| Componente | Detalle |
|---|---|
| Sistema anfitrión | Windows 11 Home |
| Emulador | DOSBox-X 2026.10.01 (`C:\DOSBox-X`), con DOSBox 0.74-3 como respaldo |
| Ensamblador | NASM 3.02 para DOS (`nasm.exe`), con el host DPMI `cwsdpmi.exe` |
| Control de versiones | Git; un commit por avance, con prefijo de parte |

El estudiante eligió DOSBox-X porque emula el controlador de teclado 8042 y el puerto paralelo, que son los dispositivos que la Parte 1 consulta directamente. `nasm.exe` y `cwsdpmi.exe` se copian a la raíz del proyecto para que DOSBox los vea como `C:\`, pero no se versionan por ser binarios de terceros (están en `.gitignore`).

El archivo `dosbox.conf` monta la raíz del repositorio como unidad `C:` y agrega la raíz al `PATH`, de modo que `C:\U9P1` y `C:\U9P2` existen tal como pide la guía. Se inicia con:

```powershell
C:\DOSBox-X\dosbox-x.exe -conf dosbox.conf
```

## Estructura del repositorio

```
salas-post1-u9/
├── README.md
├── dosbox.conf        # configuración de DOSBox-X (monta la raíz como C:\)
├── U9P1/              # Parte 1: *.ASM y *.COM
├── U9P2/              # Parte 2: *.ASM y *.COM
└── capturas/          # capturas de DOSBox-X, nombradas pN_cpM_descripcion.png
```

---

# Parte 1 — Acceso directo a puertos de E/S

## Configuración del entorno

El estudiante creó el directorio de trabajo dentro de DOSBox-X y verificó NASM:

```
mkdir C:\U9P1
nasm -v
```

La salida confirma `NASM version 3.02`.

![Entorno y NASM](capturas/p1_cp0_entorno_nasm.png)

## Paso 1 — Lectura del scancode por polling (`TECL.ASM`)

El controlador de teclado 8042 expone dos registros:

| Puerto | Registro | Propósito |
|---|---|---|
| `60h` | Data Port | Último scancode recibido o byte de respuesta |
| `64h` | Status Register | El bit 0 (OBF, Output Buffer Full) vale 1 cuando hay un dato listo en `60h` |

`TECL.ASM` sondea el puerto `64h` en el bucle `.poll` con `IN AL, 64h` y `TEST AL, 01h` hasta que OBF vale 1. Después lee el scancode con `IN AL, 60h`, lo guarda en `BL`, lo convierte a hexadecimal nibble por nibble y lo imprime con `INT 21h`, función `02h`.

Compilación y ejecución:

```
nasm -f bin TECL.ASM -o TECL.COM
TECL
```

Al presionar `A`, el programa imprime `1E`, que es el scancode *make* de esa tecla.

**Corrección respecto a la guía.** La primera ejecución con el código tal como aparece en la guía imprimió `9E` en lugar de `1E`: con las interrupciones habilitadas, el handler de la BIOS (IRQ1) leyó el puerto `60h` antes que el bucle de polling y al programa solo le llegó el código de soltar la tecla (*break* = *make* + `80h`). El estudiante agregó `CLI` antes del bucle y `STI` después de leer el dato, de modo que la BIOS no atienda IRQ1 mientras el programa sondea el puerto. Con ese cambio la salida es `1E`.

**Checkpoint 1.** `TECL.COM` compila sin errores y muestra el scancode de la tecla presionada.

![Compilación de TECL y espera de tecla](capturas/p1_cp1_tecl_compilacion.png)
![TECL muestra 1E al presionar A](capturas/p1_cp1_tecl_scancode.png)

## Paso 3 — Polling con timeout (`POLL_T.ASM`)

El bucle de `TECL.ASM` puede bloquear el programa para siempre si el dispositivo nunca responde. `POLL_T.ASM` carga `CX` con `MAX_RETRY` y usa `LOOP .poll`, que decrementa `CX` y repite mientras no sea cero. Si OBF se activa, salta a `.dato_listo` y imprime el byte leído; si `CX` llega a 0, imprime el mensaje de timeout y termina.

`MAX_RETRY` vale `0005h` por defecto en el archivo, que es el valor pequeño que pide el checkpoint, y puede cambiarse al ensamblar sin editar el código:

```
nasm -f bin POLL_T.ASM -o POLL_T.COM
nasm -f bin -dMAX_RETRY=0FFFFh POLL_T.ASM -o POLL_T.COM
```

Se hicieron dos pruebas sin presionar ninguna tecla. Con `MAX_RETRY=5` aparece el mensaje de timeout, como pide el checkpoint. Con `MAX_RETRY=0FFFFh` (el valor de la guía) el timeout también aparece: 65 535 iteraciones duran apenas unos milisegundos en el emulador, un lapso demasiado corto para que una persona presione una tecla. Esta observación respalda la decisión técnica del Paso 6: el contador mide iteraciones, no tiempo.

**Checkpoint 2.** `POLL_T.COM` muestra el mensaje de timeout cuando `MAX_RETRY` es pequeño y no se presiona ninguna tecla.

![POLL_T con MAX_RETRY=5](capturas/p1_cp2_polling_timeout_5.png)
![POLL_T con MAX_RETRY=0FFFFh](capturas/p1_cp2_polling_timeout_FFFF.png)
