# Escala propuesta: Metrópolis de Noche

Valores con los que el blockout construye la porción vertical, medidos en studs. **Es una
propuesta para que la apruebes o la cambies**, no una decisión tomada: la aprobación de arte es
tuya.

Se regenera con un comando cuando cambien los números:

```powershell
blender --background --factory-startup --python art/blender/blockout/build_blockout.py
```

Las imágenes están en `art/render/` y los números medidos, en `blockout-stats.json`.

## Valores

| Qué | Studs | Referencia |
| --- | --- | --- |
| Avatar | 6 | Unos 1,70 m. Es la unidad de todo lo demás |
| Altura de planta | 7 | Techo de 2 m escasos por planta |
| Calzada | 28 | Tres fichas de lado a lado |
| Acera | 6 por lado | Una ficha de ancho, con bordillo |
| Frente de solar | 18 | Tres solares = 54 studs, dentro del máximo de 60 entre casillas de la subfase 05 |
| Fondo de solar | 22 | |
| Ficha: base | 8 de diámetro | |
| Ficha: altura | 12 | 18 con el avatar subido |
| Ojo en primera persona | 17,1 | 12 de ficha + 5,1 del avatar |

Alturas resultantes, con los niveles de edificio de la arquitectura:

| Asset | Plantas | Alto | Triángulos (blockout) |
| --- | --- | --- | --- |
| Casa | 2 | 15,2 | 324 |
| Edificio | 5 | 36,5 | 308 |
| Rascacielos | 12 | 92 | 660 |
| Ficha taxi | — | 12 | 892 |
| Fondo de ciudad | — | 52 | 60 |

## Las tres decisiones que necesito de ti

**1. La ficha es más alta que una casa.** Con 12 studs, la ficha sola pasa del tejado de una casa
de dos plantas (15,2), y con el jinete llega a 18. En primera persona miras **por encima** de los
tejados de las casas, que es justo lo que rompe la sensación de caminar entre edificios.

- Opción A (recomendada): ficha de **9** studs, base de 6. El ojo baja a unos 14,1 y las casas
  vuelven a taparte.
- Opción B: dejar la ficha en 12 y subir las casas a 4 plantas (28 studs). Encoge la sensación de
  ciudad: todo se vuelve más alto para que lo pequeño no se pierda.

**2. La calle se lee como un cañón.** 28 studs de calzada con un rascacielos de 92 dan una
proporción de 1:3,3. En la vista de primera persona la fachada ocupa media pantalla.

- Opción A (recomendada): calzada de **34** y acera de 7. Cuesta 8 studs más por manzana.
- Opción B: mantener 28 y retranquear la fachada en las zonas altas, para que el rascacielos no
  nazca en el bordillo.

**3. El tamaño de la ficha frente a la acera.** Con base de 8 y acera de 6, la ficha no cabe en la
acera y siempre va por la calzada. Es coherente con "sin movimiento libre", pero conviene decidirlo:
o la ficha circula por la calzada (mi recomendación), o la acera crece a 9.

## Lo que este documento no decide

- Paleta, materiales, tipografía y logo: eso es la guía de estilo de la subfase 06, con la skill
  `impeccable`, y va después de la Puerta A.
- Número de barrios y composición del tablero: ya están en la arquitectura (6, 8 y 10 zonas).
- Detalle de los edificios: el blockout solo comprueba volúmenes y proporciones.
