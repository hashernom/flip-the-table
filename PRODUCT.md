# Product

<!-- impeccable:product-schema 1 -->

## Platform

roblox-pc

<!-- El esquema solo contempla web, ios, android y adaptive. Esto es un juego de Roblox y en el MVP
se juega en PC. Se registra el valor real en vez de inventar uno que encaje; el móvil queda
explícitamente fuera del MVP y se medirá en la Puerta B cuando toque. -->

## Users

Grupos de **2 a 8 amigos que ya se conocen**, en sesiones de **20 a 30 minutos**, normalmente en
partida privada. No compiten contra desconocidos ni juegan solos: el grupo es el producto.

El trabajo que hacen es quedar, jugar una partida tensa con alianzas y traiciones, y querer la
revancha. El éxito no es que la partida termine, es que **pidan otra**.

## Product Purpose

Un juego de mesa multijugador donde **cada regla importante ocurre como una escena real** en una
ciudad viva: no se juega sobre un tablero, se juega dentro de él. Si caes en la cárcel, llega la
policía; si sale un huracán, entra un huracán.

El aspecto concreto está en `art/vision-visual.md`: una calle de asfalto con casillas pintadas y un edificio real por propiedad.

Existe para dar a un grupo de amigos la tensión de un juego de mesa clásico con el espectáculo de
un videojuego moderno, sin apuestas y sin ventajas de pago.

## Positioning

**Todo el grupo ve la misma escena al mismo tiempo.** Las reglas de mesa se resuelven como
cinemáticas compartidas en una ciudad a escala, y nadie se pierde la ruina de su amigo porque todos
están mirando lo mismo. Un juego de mesa no puede hacer eso; un videojuego de tablero estático,
tampoco.

## Operating Context

- Roblox, primera persona sobre una ficha gigante que recorre la ciudad. Sin movimiento libre: se
  avanza solo con los dados.
- Vista general en maqueta con un botón, y cámara de escena cuando una regla se resuelve.
- Partidas privadas para el grupo; tamaños de 32, 40 y 48 casillas según número de jugadores.
- Se juega con menús: pactos, votos y duelos no exigen reflejos.

## Capabilities and Constraints

- **Motor de reglas puro en Luau**, verificado con Lune sin Roblox. La plataforma va aparte.
- **Apto para todo público** es un límite fijo del producto, no una preferencia de estilo.
- **Sin monetización en el MVP.** Se decide antes de publicar; no entra por la puerta de atrás.
- **Sin apuestas y sin pagar para ganar**, en ninguna fase.
- **Nada de la marca Monopoly**: ni logo, ni personaje, ni diseño de tablero reconocible, ni
  símbolos de casino.
- **Assets propios**: cada modelo se aprueba por una persona, con estándar de la ficha y manifiesto
  técnico que rechaza lo que no cumple presupuesto o LOD.
- **Límite de Roblox**: 20 000 triángulos por malla; los presupuestos del juego son menores.
- **El móvil no entra en el MVP.** El rendimiento queda sin verificar hasta la Puerta B.
- Decidido pero pendiente: nombre definitivo y comprobación legal antes de publicar.

## Brand Commitments

- **Nombre provisional: Flip the Table.** No es definitivo.
- **Manhattan de día**, con la Zona Alta de cristal y oro: luz natural y arquitectura, no ciudad
  nocturna de neón.
- **Tono juguetón y caricaturesco.** La traición y la ruina ajena se celebran con humor, sin
  crueldad; los arrestos parecen de dibujos animados.
- **Sin personas en la ciudad.** Con fichas gigantes y nadie caminando, se lee como una maqueta de
  lujo. Los NPC no forman parte del lenguaje visual.
- **Los visuales son el punto fuerte declarado.** La ciudad se juzga por su calidad, no por su
  cantidad.

## Evidence on Hand

- `docs/00-ficha/ficha-propuesta.md`: fuente de verdad del juego.
- `docs/01-arquitectura/arquitectura.md`: módulos y contratos.
- `docs/02-mvp/`: diez subfases con sus puertas.
- `art/`: banco de pruebas con calle completa, cuatro recetas de fachada, skybox propia, cuatro
  sets CC0 y la tubería de assets validada de punta a punta.
- Medido, no estimado: fachada de referencia de **2 074 triángulos** con LOD de 790; calzada de 34
  studs; ficha de 9; ojo de cámara a 14,1.

**Ausencias que no se deben inventar:** no hay partidas con amigos todavía, ni encuestas, ni
métricas de retención, ni números de rendimiento en móvil.

## Product Principles

1. **Toda regla importante es una escena, y todos la ven a la vez.**
2. **Impredecible de verdad:** ninguna estrategia puede depender de saber qué evento viene.
3. **La traición divierte; no humilla.** Apto para todo público es un límite, no un filtro.
4. **Nada que se parezca a una apuesta.** El azar existe; el riesgo de dinero, no.
5. **Calidad antes que cantidad:** una manzana impecable vale más que una ciudad a medias.

## Accessibility & Inclusion

Apto para todo público: sin violencia gráfica, sin lenguaje soez y sin mecánicas que exijan
reflejos. La información de la partida debe leerse sin depender del color solo. El MVP se juega en
PC; la accesibilidad en móvil se revisará cuando entre el móvil.
