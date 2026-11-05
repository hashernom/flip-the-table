# Boceto HUD de Flip the Table: reglas y contenido comunes

Archivo HTML autónomo, primer viewport 1440 x 900, `height:900px; overflow:hidden`. CSS en línea, sin JavaScript, nada externo salvo Google Fonts (Luckiest Guy, Oswald, Source Sans 3). Menos de 200 líneas. Escribe solo tu archivo.

## Tokens (no inventes otros)
Asfalto #23272C · Caliza #EDE5D3 · Amarillo taxi #F5C518 · Rojo señal #C4382B · Naranja obra #E07A3C.
Nunca verde fieltro. Sin degradados, sombras difusas, brillos, glass, esquinas muy redondeadas (radio máximo 3 px), emoji ni glifos de fuente como iconos: las marcas se dibujan con SVG en línea de un solo trazo.

## Tipografía
- Luckiest Guy: solo el verbo del botón, 34 px, mayúsculas. Nunca en otra cosa.
- Oswald, mayúsculas con letter-spacing .1em: nombres, etiquetas, cifras grandes. Mínimo 12 px.
- Source Sans 3: textos y dinero en HUD (font-variant-numeric: tabular-nums). Dinero con punto de miles: 1.240.

## Componentes
- Fondo de la ciudad: NO una foto. Plano simple que sugiere la calle: cielo #AFC7D6, una banda de edificios en bloques planos #B0664A #D2C9B4 #7FB2D9 #8C8F92, asfalto #4A4E54 con línea discontinua clara, y una casilla pintada #DC2626 de filete claro en el centro. Debe verse la ciudad: es lo importante.
- Placa de jugador: asfalto al 92 % de opacidad con filete caliza de 1 px. Dentro: nombre en Oswald 15, dinero en Source Sans 24 tabular a la derecha, y debajo marcas pequeñas (icono SVG + texto Oswald 12). Un disco de 12 px con el color del asiento y la inicial no hace falta; basta un cuadrito de 10 px del color del asiento.
- El jugador con turno: placa con franja gruesa de caliza de 4 px a la izquierda y un triángulo SVG. El único amarillo de la pantalla es el botón COMPRAR.
- Escritura (carta 2:3, 240 x 360 px, se escala): bloque de zona a sangre del color #DC2626 de un tercio del alto con «DISTRITO CARMESÍ» en Oswald 12 y «CINE LUX» en Oswald 31 en caliza, símbolo SVG de llama arriba a la derecha; barra de precio en asfalto «PRECIO» + «260» Oswald 33; tabla sobre caliza: Sin mejoras 26 · 1 casa 104 · 2 casas 156 · 3 casas 260 · Hotel 416 · Rascacielos 624 en Source Sans 13,5 tabular, con un filete rojo a la izquierda de las tres filas de casas y regla de 2 px cerrando; pie en asfalto.
- Botón de acción: placa amarilla #F5C518, texto asfalto Luckiest Guy 34 «COMPRAR», borde asfalto 2 px y filete interior de 2 px asfalto. Debajo o al lado, botón secundario: contorno caliza sobre asfalto, Oswald 14 espaciado, «NO COMPRAR · SUBASTA». Debajo, atajos en Oswald 12: «ESPACIO» y «N».
- Línea de plazo (lo distintivo): línea discontinua de calzada, trazos de 28 x 6 px, separados 16 px, color naranja obra. Se consume: la parte ya agotada se ve en caliza al 25 %. Al lado, la cifra «14 s» en Oswald 20 caliza.
- Barra de ronda: pequeña, en un sitio discreto: «RONDA 7/12» y «TURNO DE ANA», Oswald 14. Junto a ella dos botones secundarios: «VISTA GENERAL» y «EMOTES», mínimo 44 px de alto.
- Minimapa: cuadrado de 180 px asfalto 92 %, anillo de 56 casillitas de color, tres fichas como pequeños triángulos o rombos.
- Mano del jugador: tres dorsos o tres pestañas muy compactas con «MULTA», «ESCUDO», «HURACÁN» y sello de rareza por forma (contorno fino, doble filete, bloque rojo inclinado), en Oswald 12.

## Jugadores (orden de turno; contenido real)
1. ANA · 1.240 · #E85D9E · marca CORONA
2. SANTI (TÚ) · 860 · #22D3EE · 2 cartas · con turno
3. MARÍA JOSÉ · 2.105 · #F59E0B · marca TRAIDOR (rojo señal como relleno de una etiqueta con texto caliza)
4. LUCAS · 415 · #8B5CF6 · FURIA 3/5
5. VALEN · 0 · gris · ESPECTRO (placa más apagada)
6. NICO · 1.030 · #10B981
7. CAMI (BOT) · 780 · #4F46E5
8. GUILLERMO ANTONIO · 1.560 · #C97B3A (el nombre más largo: no debe cortarse)

La barra dice «TU TURNO». Textos en español, sin nada inventado más allá de esto.
