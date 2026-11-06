# Visión visual: cómo debe verse el juego

**Es una ciudad viva con una calle que recorre el tablero: caminas por una avenida, y cada casilla es un tramo de calle con su edificio real al lado.** Lo decidió el responsable el 2026-11-04. Si un plan, un asset o una escena lo contradice, manda este documento, y la [ficha](../docs/00-ficha/ficha-propuesta.md) por encima de todo.

Las reglas no cambian: son las del juego clásico de propiedades con sus cinco pasos de construcción. Esto solo define cómo se ven.

## La imagen que hay que tener en la cabeza

Tu ficha, con tu avatar encima, recorre una avenida de asfalto, de día, y la cámara la sigue desde el aire. A los lados pasan aceras, árboles y farolas, y detrás de cada acera hay un edificio distinto: un cine, un mercado, un almacén. En el asfalto, junto a cada edificio, hay pintado un rectángulo del color de su zona. Por el color y su disposición sabes que estás en un juego de mesa; por todo lo demás, sientes que estás en una ciudad.

## Las cuatro reglas

### 1. La calle es de asfalto, no un tablero

- El asfalto es continuo a lo largo de toda la ruta, con línea discontinua en el eje, bordillos y aceras.
- Nunca hay baldosas blancas ni un tablero impreso bajo la ciudad.
- Las esquinas de la ruta se leen como cruces de calles.

### 2. Cada casilla es pintura sobre el asfalto

- Cada casilla conserva su color y su sitio, como pintura vial sobre el carril junto a su edificio.
- Mide **30 de largo por 16 de fondo**: la otra mitad de la calzada queda libre, y entre una casilla y la siguiente se ven **10 studs de asfalto**. Las casillas no son gigantes: el asfalto y la separación entre edificios se tienen que apreciar.
- Lleva un filete claro, y el símbolo de su zona pintado, para quien no distingue el color.
- El nombre va pintado en el asfalto, en el carril libre junto a la casilla, para que ninguna ficha lo tape. No hay postes ni textos flotando (decisión del responsable, 2026-11-04).

### 3. Cada propiedad es un edificio real y propio

- Es un edificio de ciudad modelado en 3D, distinto de los demás y coherente con su nombre: el Cine Lux es un cine y el Mercado de la Séptima, un mercado.
- Está ahí desde el inicio de la partida, tenga o no dueño. Una propiedad sin comprar lleva cartel de venta; una comprada, una placa del color de su dueño.
- Entre edificios vecinos queda aire: acera, un árbol o una farola.

### 4. Las mejoras no cambian de edificio

Los cinco pasos (una, dos y tres casas, hotel y rascacielos) suben la renta como en el juego clásico. Se ven de dos formas:

- **Marcadores:** pequeñas piezas junto al edificio, a un lado de la entrada, que dicen el nivel de un vistazo.
- **Añadidos:** el edificio mejora un poco. Va ganando toldos, una fachada más cuidada, una planta o un remate, y al máximo una coronación que se reconoce. Sube un poco, siempre reconocible como el mismo edificio.

**El aspecto sale siempre del nivel que manda el motor** (R-P50). Las catástrofes quitan marcadores y añadidos, y el cuerpo del edificio queda en pie. Las grietas y el humo duran lo que la escena: no hay daños permanentes.

## Cámara y mapa

**La cámara es para el espectáculo; el minimapa, para jugar.** No hay primera persona, porque la ciudad y los personajes tienen que verse. Todo el grupo ve lo mismo:

- **Antes de tirar y al decidir:** cámara aérea alejada, por el interior del anillo, con las fachadas de frente y las casillas que vienen a la vista.
- **Recorrido:** se acerca a la ficha y al avatar.
- **Escena:** la misma para todos, y manda sobre lo demás.

El tablero se conoce siempre sin depender de esa cámara:

- **Minimapa:** siempre en pantalla, con todas las casillas, su color, dueño, nivel y las fichas.
- **Detalle:** al pulsar una casilla, sin mover la cámara de nadie, también en el turno de otro.
- **Vista general:** toda la ciudad real desde arriba, con un botón.

**Consecuencias para el arte:** los tejados se ven, así que necesitan detalle. El centro del anillo tiene que ser bajo, para no tapar la cámara. La ficha ya no está atada a la altura de un ojo y puede crecer si no se lee bien.

## El resto de la ciudad

- **Ambiente de ciudad viva:** árboles, farolas, bancos, pasos de cebra, coches y taxis en movimiento. Sin peatones, como ya está decidido: la ciudad se lee como una maqueta de lujo.
- **Dentro del anillo:** una plaza con fuente y parque y algún edificio singular. El skyline de fondo se quitó el 2026-11-06: lo sustituye el fondo de cada barrio, que llega con el plan 07; hasta entonces, el exterior queda libre.
- **Luz:** de día, la de [luz.md](luz.md). No hay atardecer ni neón nocturno.
- **Identidad:** la de la [guía de estilo](guia-de-estilo.md), dirección Señalética.

## Lo que no se hace

- **Ningún elemento de marca del juego original:** ni su nombre, ni sus logotipos, ni el personaje. Sus fichas tampoco: nada de caballo, sombrero o zapato de plata, porque las fichas son propias, como el taxi. Tampoco casas verdes ni hotel rojo.
- **Ni edificios genéricos** con rótulos como «HOTEL» o «BANK»: cada lugar tiene su nombre propio.
- **Ni estética de casino**, como dice la guía de estilo en §9.
- **Ni sustituir el edificio por otro modelo** al subir de nivel.

## Referencias

- **Modelo de ejemplo:** el Cine Lux, en `art/blender/slice/build_cine_lux.py`. Sus seis estados se ven en [cine-lux-niveles.png](render/cine-lux-niveles.png).
- **Imagen de concepto:** el responsable generó una con IA, útil para el ambiente de ciudad viva, con la plaza y el anillo de casillas. No está en el repositorio, porque contiene marca del juego original, y no se copia: tiene baldosas blancas gigantes, atardecer y un caballo de plata, que son justo lo que este documento descarta.
- **Medidas:** las de [escala.md](escala.md), y los valores en `src/shared/config/CityLayout.luau`.
