# Luz y atmósfera: el look suave

Cómo se consigue en Roblox ese aspecto blando y cuidado de los juegos modernos: sombras suaves,
ambiente levantado, cielo con bruma y un tono de color que unifica. Es una pila de capas, no un
ajuste.

**Estado:** probado en Studio con la calle del blockout el 2026-11-02. Los valores de abajo son el
punto de partida, no la receta final: cada barrio los ajusta.

## Las siete capas, por orden de impacto

**1. Cielo propio.** Es la capa que más delata. Con el skybox por defecto, cualquier escena parece
de Roblox por muy bien iluminada que esté, y **no se arregla por código**: subir `Atmosphere` a
0,78 de densidad no cambia el azul. Hace falta una skybox subida como asset.

**2. Hora del sol.** `Lighting.ClockTime` entre 8 y 10, o entre 15 y 17. Nunca a mediodía: la luz
cenital es plana y no da sombras largas. A media tarde las fachadas reciben luz rasante y la calle
gana profundidad.

**3. La luz.**

| Ajuste | Valor |
| --- | --- |
| `Brightness` | 2,0 a 2,6 |
| `Ambient` | 58 a 112 en cada canal |
| `OutdoorAmbient` | 92 a 155 |
| `ShadowSoftness` | 0,6 |
| `EnvironmentDiffuseScale` | 0,5 |
| `EnvironmentSpecularScale` | 0,8 |
| `ExposureCompensation` | −0,1 a 0,15 |
| `GlobalShadows` | activado |

La clave está en el ambiente: si `Ambient` y `OutdoorAmbient` están a cero, las sombras se comen a
negro y la escena se ve dura. Levantarlos es lo que da el aire "cómodo".

**4. Atmósfera.** `Atmosphere` con `Density` de 0,3 a 0,5 y `Haze` de 1,6 a 2,2. Da perspectiva
aérea: lo lejano pierde contraste y saturación, que es como funciona el ojo. Sin esto, todos los
edificios compiten con la misma nitidez.

**5. Post-proceso.**

| Efecto | Valor |
| --- | --- |
| `BloomEffect` | `Intensity` 0,4 a 0,6, `Threshold` 1,3 a 1,4 |
| `ColorCorrectionEffect` | contraste 0,06 a 0,12, saturación 1,04, tinte cálido suave |
| `DepthOfFieldEffect` | `FarIntensity` 0,16 a 0,18, foco a 70, radio 120 |
| `SunRaysEffect` | `Intensity` 0,08 |

Bloom bajo y con umbral alto: sirve para que los blancos florezcan un poco, no para hacer neón.

**6. Relleno.** `PointLight` con `Shadows = false` y brillo 0,7 a 0,9 por fachada. Son luces que no
existen en la ficción pero quitan los negros duros. Es el truco más barato de todos.

**7. Materiales.** `MaterialService.Use2022Materials = true`, y variedad de material por edificio
(`Limestone`, `Brick`, `Granite`, `Marble`). Los colores con valor tonal, nunca blanco puro: bajo el
sol se queman y se pierde toda la forma.

## Lo que esta prueba demostró que no se puede hacer

- **`Lighting.Technology` no se puede leer ni escribir por script** (exige capacidad `RobloxScript`).
  Se ajusta a mano en el panel de propiedades.
- **`Lighting.Tonemapper` tampoco**: el intento por script falló.
- **El cielo no se arregla sin asset.** Es el techo de esta prueba.

## Qué falta para que esto sea "profesional"

La luz sola lleva la escena de gris plano a decente. El salto grande son los assets, en este orden:

1. **Skybox** con nubes propias (lo primero, es lo que más se nota).
2. **Texturas PBR** por `SurfaceAppearance`: rugosidad variable en fachadas y asfalto. Es lo que
   hace que la luz "se pegue" a la superficie en vez de resbalar.
3. **Mallas de verdad**: ventanas con marco, cornisas, toldos, marquesinas. Una caja con textura
   sigue siendo una caja.
4. **Props de calle**: farolas, hidrantes, buzones, señales, camiones. La densidad es lo que hace
   que una calle parezca habitada.

Esto es, literalmente, las tareas 1 a 3 de la subfase 06 más el plan 07. La captura
`art/render/lookdev-luz-suave.jpg` es el máximo alcanzable **sin** ninguno de esos cuatro.

## Cómo se encienden las sombras (resuelto)

En los places con **luz unificada** ya no existe `Lighting.Technology`: el motor va en `Future` por
defecto y lo que queda por decidir es el estilo. La propiedad es **`Lighting.LightingStyle`**:

| Valor | Qué hace |
| --- | --- |
| `Soft` | El aspecto antiguo: sin sombras dinámicas de piezas. |
| `Realistic` | Sombreado físico y sombras arrojadas. Es el que hay que usar. |

Está en **Explorer → Lighting → Properties**, sección *Appearance*. Es un ajuste manual: la
propiedad no es escribible por script, igual que `Technology`.

Síntoma de tenerlo en `Soft`: la escena se ve plana, sin una sola sombra arrojada, por mucho que
`GlobalShadows` esté activado y `ShadowSoftness` a cero. Con `Realistic` aparecen las sombras de
edificios, farolas y vehículos.

Ajustes que funcionaron con sombras reales: `ClockTime` 9,4, `Brightness` 2,45, `Ambient` 44/48/60,
`ShadowSoftness` 0,18, sol con elevación de unos 48°, y la `Atmosphere` a 0,26 de densidad para que
la bruma no se coma las sombras lejanas.

## Con assets: hasta dónde llega

`art/render/lookdev-cielo-pbr.jpg` es la misma calle con la skybox y los tres sets PBR de
`art/generators/pbr_assets.py` ya aplicados. El cielo deja de ser de Roblox y las fachadas dejan
de ser cajas lisas, pero **las sombras de los edificios siguen sin leerse**: en esa prueba el sol
está detrás de la manzana. Queda pendiente:

- Elegir la hora del día de cada barrio y comprobar dónde caen las sombras desde la cámara real.
- Bajar los albedos claros: la caliza a 214 se quema a plena luz y pierde toda la forma.
- Tapar el horizonte vacío con skyline de fondo y más bruma, o se ve el borde del mundo.


## Regla

Ningún preset de luz se da por bueno sin mirarlo en el juego, en el móvil de referencia y con
calidad gráfica mínima. Un ajuste que se ve precioso en PC puede quedar plano en un móvil de gama
media, y ese es el público del MVP.
