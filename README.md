# BackCraft — aplicación nativa macOS

SwiftUI + AppKit + AVFoundation. No requiere Python, Node ni dependencias externas
para ejecutarse. El instalable está en `dist/BackCraft-1.0.0-arm64.dmg`.

## Compilar y empaquetar

Requiere Xcode Command Line Tools con Swift y SDK de macOS compatibles.
Para empaquetar el DMG se necesita además una sesión gráfica y permitir a la
terminal automatizar Finder. El script guarda el fondo Retina, las posiciones
de los iconos y el tamaño de ventana antes de comprimir la imagen de disco.

```sh
bash BackdropNative/build.sh
bash BackdropNative/package.sh
open "BackdropNative/BackCraft.app"
```

Objetivo: Apple Silicon, macOS 14+. Compilada y ejecutada en el Mac de desarrollo;
no se ha ejecutado en macOS 14 ni en Intel. Firma local ad hoc, sin notarización.

Renombrada desde Backdrop Studio. Mantiene el identificador de aplicación
`local.backdropstudio.app` y `~/Library/Application Support/Backdrop Studio`
para conservar la biblioteca existente. Cierra la versión anterior antes de
abrir BackCraft; ambas versiones comparten almacenamiento.

## Funciones implementadas

- Navegación oscura, destacado, carruseles, biblioteca en cuadrícula e inspector.
- Importación validada de imágenes y vídeos con copia a almacenamiento propio.
- Miniaturas de contenido real y previsualización de vídeo.
- Búsqueda, categorías, ordenación, nombres editables y favoritos persistentes.
- Listas persistentes y rotación mientras la aplicación está abierta.
- Fondos estáticos mediante `NSWorkspace.setDesktopImageURL`.
- Fondos de vídeo con AVPlayerLooper en ventanas del nivel de escritorio,
  bajo los iconos, sin capturar clics, con selección de pantalla y pausa.
- Seis fondos abstractos originales generados a 2560 × 1440.

La selección estática se aplica a las pantallas disponibles en el contexto de
Spaces actual; no se promete modificar todos los Spaces ni la pantalla de bloqueo.
Un nuevo fondo sustituye la sesión de vídeo anterior. La app no mantiene
asignaciones distintas de vídeo por monitor ni restaura la reproducción al reiniciar.

## Evidencia y alcance

La referencia de Descubrir se observó con REA, captura y accesibilidad:
`ev_3f2404d09c7dbf65fe9910a0daa955e0555184494a2e8e6c0a953e873bb05ad3`.
Biblioteca e inspector vacío:
`ev_9ca9798d8239aa883cb3452994d9f47e8f1e8d4d4e3795f200d2f484a71b866b`.
Arranque de Studio observado:
`ev_be8fe5d72854d80f95b84ba4d2e0678d9513e25024294e182feef7cd41889236`.

Es una reproducción parcial del diseño y de los flujos locales, no equivalencia
completa. No incluye catálogo Cindori, cuentas, iCloud, licencias, actualización,
agente persistente ni integración de vídeo en pantalla de bloqueo.

## Verificación

`build.sh` compila, firma y ejecuta pruebas aisladas (`--self-test`): biblioteca
inicial, miniatura PNG real, persistencia, importación gestionada, rechazo de
imagen inválida y limpieza de referencias de listas al quitar un fondo.
Estas pruebas no cambian el fondo del usuario y no prueban por sí solas la
reproducción de vídeo ni la integración de escritorio. El arranque gráfico se
observó con REA. `package.sh` verifica la integridad de la imagen con hdiutil.
