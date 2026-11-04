# Escala de la ciudad

Valores vigentes, en studs, aprobados por el responsable el 2026-11-02. La fuente es
`art/blender/blockout/build_blockout.py`: si cambia un número, se regenera el blockout y se
vuelven a mirar las vistas de `art/render/`.

```powershell
blender --background --factory-startup --python art/blender/blockout/build_blockout.py
```

## Valores

| Qué | Studs | Referencia |
| --- | --- | --- |
| Avatar | 6 | Unos 1,70 m. Es la unidad de todo lo demás |
| Altura de planta | 7 | Techo de 2 m escasos por planta |
| Calzada | 34 | Cuatro fichas de lado a lado |
| Acera | 7 por lado | Con bordillo; la ficha no cabe y circula por la calzada |
| Frente de solar | 18 | Tres solares = 54 studs, dentro del máximo de 60 entre casillas de la subfase 05 |
| Fondo de solar | 22 | |
| Ficha: base | 6 de diámetro | |
| Ficha: altura | 9 | 15 con el avatar subido |
| Ojo en primera persona | 14,1 | 9 de ficha + 5,1 del avatar |

Alturas con los niveles de edificio de la arquitectura:

| Asset | Plantas | Alto | Triángulos (blockout) |
| --- | --- | --- | --- |
| Casa | 2 | 15,2 | 324 |
| Edificio | 5 | 36,5 | 308 |
| Rascacielos | 12 | 92 | 660 |
| Ficha taxi | — | 9 | 892 |
| Fondo de ciudad | — | 52 | 60 |

## Por qué estos y no otros

**La ficha mide 9, no 12.** Con 12, el jinete subía a 18 studs y pasaba por encima del tejado de
una casa de dos plantas: en primera persona veías tejados desde arriba, que es lo que rompe la
sensación de caminar entre edificios. Con 9, el ojo queda en 14,1 y el tejado de la casa (15,2)
vuelve a tapar el horizonte.

**La calzada mide 34, no 28.** Con 28 y un rascacielos de 92, la proporción era 1:3,3 y la fachada
se comía media pantalla desde la ficha. Con 34 queda en 1:2,7, que se lee como avenida y no como
callejón. Cuesta 8 studs más por manzana.

**La ficha circula por la calzada.** Con base de 6 y acera de 7, cabe justa pero va a ras del
bordillo, y el juego no tiene movimiento libre: la ficha siempre está en su casilla de la calzada.
La acera queda para los viandantes, el mobiliario y las escenas.

## Lo que esta escala condiciona

- **Cámaras.** Cualquier cámara de juego que baje de 14 studs ve el tejado de las casas, no la
  calle. La vista general (maqueta) tiene que compensar.
- **Casillas.** La subfase 05 limita a 60 studs la distancia entre casillas consecutivas. Con tres
  solares de 18 por manzana son 54, así que la ruta entra sin acercarse al límite. El peor caso con
  48 casillas serían 2 880 studs de recorrido.
- **Edificios.** El rascacielos de 92 es el techo del juego. Si una zona pide más altura, se
  cambia el número de plantas, no la escala.

## Lo que no decide este documento

- Paleta, materiales, iluminación, tipografía y logo: guía de estilo de la subfase 06, con la
  skill `impeccable`, sin esperar a la Puerta A (aplazada hasta la alpha).
- Composición del tablero y número de barrios: ya están en la arquitectura (6, 8 y 10 zonas).
- Detalle de los edificios: el blockout solo comprueba volúmenes y proporciones.
