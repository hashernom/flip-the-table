# Contenido del tablero: zonas, colores y propiedades

Fuente de verdad de los nombres, colores, tramas y precios del tablero de Metrópolis. Son **12 zonas y 34 propiedades**; cada zona tiene 2 o 3 propiedades y cada barrio agrupa dos o más zonas.

Todos los nombres y colores son propios: no se usan los del juego original ni sus nombres de propiedades.

## Zonas

| Zona | Barrio | Color | Trama | Props | Precio 40 | Precio 48 | Precio 56 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Callejón del Cobre | Centro | Cobre `#C97B3A` | remaches | 2 | 60 | 60 | 60 |
| Pasaje Cian | Centro | Cian `#22D3EE` | ondas | 3 | 110 | 100 | 90 |
| Bulevar Magenta | Centro | Magenta `#E85D9E` | rombos | 3 | 160 | 140 | 120 |
| Feria Naranja | Centro | Naranja `#F59E0B` | rayos | 3 | 210 | 170 | 150 |
| Distrito Carmesí | Centro | Carmesí `#DC2626` | llamas | 3 | 250 | 210 | 180 |
| Paseo Limón | Centro | Limón `#FACC15` | estrellas | 3 | 300 | 250 | 220 |
| Dársena Esmeralda | Puerto | Esmeralda `#10B981` | olas | 3 | 350 | 290 | 250 |
| Muelle Violeta | Puerto | Violeta `#8B5CF6` | luna | 2 | 400 | 320 | 280 |
| Mirador Añil | Zona Alta | Añil `#4F46E5` | constelación | 3 | — | 360 | 310 |
| Cumbre Blanca | Zona Alta | Blanco hueso `#E7E5E4` | copo | 3 | — | 400 | 340 |
| Distrito Grafito | Industrial | Grafito `#64748B` | hexágonos | 3 | — | — | 370 |
| Sector Ocre | Industrial | Ocre `#A16207` | ladrillos | 3 | — | — | 400 |

Las dos zonas de 2 propiedades son **Cobre** (la más barata) y **Violeta** (la más cara del tablero de 40). El precio se reparte de 60 a 400 dentro de cada tablero, por eso la misma zona cuesta distinto según el tamaño.

## Propiedades

**Cobre (2)**

1. Barbería Morro
2. Callejón del Hojalatero

**Cian (3)**

3. Pasaje Burbuja
4. Calle del Cable
5. Caldas

**Magenta (3)**

6. Centro Páez
7. Neo Mundo
8. Plaza del Neón

**Naranja (3)**

9. Mercado de la Séptima
10. llaneradas.com
11. Calle del Azafrán

**Carmesí (3)**

12. Plaza del Jazz
13. Cine Lux
14. Bodega La Reserva

**Limón (3)**

15. Vereda La Mata
16. Villa Margarita
17. Panadería La Espiga

**Esmeralda (3)**

18. Muelle de los Pescadores
19. Astillero Neptuno
20. Acuario La Sirena

**Violeta (2)**

21. Versalles 1
22. Versalles 2

**Añil (3)**

23. Observatorio Cerro Azul
24. D.T
25. Torres de Aragón

**Blanca (3)**

26. Tajamar
27. Cacique
28. Monviso

**Grafito (3)**

29. Fundición Vulcano
30. Chatarrería El Imán
31. Estación de Metrolínea

**Ocre (3)**

32. Almacén El Ladrillo
33. Curtiembre Los Nogales
34. Fábrica de Ladrillos La Hormiga

`llaneradas.com` es la única propiedad con forma de dominio. **Versalles 1** y **Versalles 2** son las dos propiedades de Muelle Violeta: comparten zona y color, y son el único par de gemelas del tablero. En el rótulo 3D, «llaneradas» va grande y «.com» pequeño, para que se lea desde la calle.

## Escalera de construcción

| Nivel | Estado | Coste del paso | Coste acumulado | Multiplicador | Renta en 60 | Renta en 400 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Sin mejoras | — | — | × 1 (× 2 con zona) | 12 | 80 |
| 1 | 1 casa | 50 % | 50 % | × 2 | 24 | 160 |
| 2 | 2 casas | 50 % | 100 % | × 3 | 36 | 240 |
| 3 | 3 casas | 50 % | 150 % | × 5 | 60 | 400 |
| 4 | Hotel | 50 % | 200 % | × 8 | 96 | 640 |
| 5 | Rascacielos | 50 % | 250 % | × 12 | 144 | 960 |

- La renta es precio × 10 % × multiplicador del nivel; con la zona completa se aplica además el × 2.
- Los efectos dinámicos (rondas finales, Zona Caliente, Inflación, presión) se aplican aparte y están topados a × 4.
- El hotel exige las 3 casas, y el rascacielos, el hotel. Los nombres son los de la regla: el edificio de la propiedad no se sustituye. Cada nivel pone sus marcadores y su añadido (ficha, «Zonas reales»), y el aspecto sale siempre del nivel que manda el motor.
- La zona completa se exige para construir: 2 compras en Cobre y Violeta, 3 en el resto.
- Constructor descuenta un 20 %. Terremoto y Demolición bajan un nivel; en bancarrota se venden niveles a la mitad.

## Tableros

| Tablero | Jugadores | Cuadrícula | Casillas | Zonas | Propiedades | Especiales |
| --- | --- | --- | --- | --- | --- | --- |
| S | 2 a 4 | 11 × 11 | 40 | 8 | 22 | 18 |
| M | 5 a 6 | 13 × 13 | 48 | 10 | 28 | 20 |
| L | 7 a 8 | 15 × 15 | 56 | 12 | 34 | 22 |

- **S:** Cobre a Violeta (Centro y Puerto).
- **M:** añade Añil y Blanca (Zona Alta).
- **L:** añade Grafito y Ocre (Industrial).

Casillas especiales por tablero: Salida 1, Tribunal 1, Impuesto 1, Giro 6 / 7 / 8, Mercado Negro 2, Duelo 2, Portal 3 y Cartelera 2 / 3 / 4. Las esquinas son Salida, Tribunal, Aduana (Impuesto) y Portal central.
