# Encargo de identidad visual

Brief para las tres direcciones visuales de Metrópolis (subfase 06, Tarea 1, Paso 1). No decide el
estilo: fija el encargo, los límites y el formato de entrega para que la decisión sea del
responsable con algo delante.

## Qué tiene que expresar la identidad

- **No es un tablero: es una ciudad.** La identidad no puede parecer un juego de mesa impreso.
- **Tono juguetón y caricaturesco**, apto para todo público. La traición se celebra con humor; los
  arrestos son de dibujos animados.
- **Manhattan de día** en Centro y Puerto, **cristal y oro** en la Zona Alta.
- **Sin NPCs**: la ciudad es una maqueta de lujo. La identidad debe sostener esa lectura.
- **Los visuales son el punto fuerte declarado.** Si hay que elegir, gana la calidad sobre la
  cantidad.

## Límites duros (no se negocian en la dirección)

- Sin la marca Monopoly: ni logotipo, ni personaje, ni tablero reconocible, ni símbolos de casino.
- Sin apuestas y sin estética de casino.
- Apto para todo público: nada de violencia gráfica ni lenguaje soez.
- Nombre **provisional**: Flip the Table. La dirección debe funcionar con otro nombre.
- Debe ser viable en Roblox: presupuesto de triángulos, materiales y fuentes reales.

## Anclas que ya existen en la escena

La identidad debería conversar con lo que ya está construido, no con una idea abstracta:

- Ladrillo rojo desgastado, caliza, hormigón y asfalto de los cuatro sets CC0
  (`art/textures/cc0/`, ids en `art/asset-ids.json`).
- Skybox propia de día, con nubes suaves y cielo azul claro.
- Cuatro recetas de fachada: piedra, balcones, toldos y ladrillo.
- Capturas reales en `art/render/` — mirarlas antes de proponer una paleta.

## Tipografía: lo que Roblox permite de verdad

- **Fuentes integradas** (`Enum.Font`), sin subir nada. Candidatas por carácter: `FredokaOne` y
  `LuckiestGuy` (juguetonas), `Bangers` y `PermanentMarker` (cómic), `Nunito` y `Roboto` (texto),
  `Oswald` y `Michroma` (titulares de ciudad).
- **Fuente propia subida** con `Font.fromAssetId`: da identidad real, pero hay que comprobar la
  licencia antes de usarla y subir el archivo a la cuenta.

Cada dirección debe decir cuál usa y por qué, y comprobar que existe.

## Formato de entrega

Por cada una de las tres direcciones:

1. **Nombre** y la idea en una frase.
2. **Paleta** con valores (hex y el equivalente para Roblox) y el papel de cada color: base, acento,
   aviso, prohibido.
3. **Tipografía**: titular y texto, con la fuente concreta y su uso.
4. **Logotipo**: tratamiento del nombre, cómo se lee a tamaño icono y qué evitar.
5. **Cómo se distingue** de las otras dos en una frase.
6. **Riesgo**: qué puede salir mal si se elige esta.

Y una **lámina PNG por dirección** con la paleta y muestras de tipografía, para decidir mirando.

Además, una **recomendación razonada** de cuál elegir y por qué, sabiendo que la decisión es del
responsable.

## Criterios de aceptación de la guía que venga después

Estos salen de `docs/02-mvp/plan-06-base-de-arte.md` y no son invento de este brief:

- Paleta con valores de color de Metrópolis con luz de día.
- Tratamiento del título, fuentes y usos, comprobando que existan o se puedan usar en Roblox.
- Biblioteca de materiales: asfalto seco, caliza, ladrillo, cristal, acero pulido, oro y agua.
- Aspecto distinto y reconocible de Centro, Puerto y Zona Alta.
- Escala de las fichas respecto a calles y edificios.
- Qué evitar: marca original, personaje, tablero reconocible y símbolos de casino.
- Tres imágenes conceptuales de la ciudad aprobadas por el responsable.

## Lo que NO hay que hacer

- No reabrir la escala, la luz ni la decisión de ciudad diurna: están tomadas y documentadas en
  `art/escala.md` y `art/luz.md`.
- No proponer ciudad nocturna de neón.
- No inventar métricas, partidas de prueba ni aprobaciones.
- No escribir `DESIGN.md` antes de que el mundo visual esté elegido.
