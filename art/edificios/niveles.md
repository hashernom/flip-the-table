# Niveles y añadidos

Cómo crece una propiedad sin cambiar de edificio. Las medidas y el flujo están en [blueprint.md](blueprint.md); aquí queda el contrato de diseño.

## Los seis estados

| Nivel | Nombre | Qué añade | Marcador |
| --- | --- | --- | --- |
| 0 | Sin mejoras | El cuerpo, solo | Ninguno |
| 1 | 1 casa | Toldo o marquesina | Ninguno |
| 2 | 2 casas | Mejora de fachada | Ninguno |
| 3 | 3 casas | Algo que cambie la silueta | Ninguno |
| 4 | Hotel | Ampliación visible | Ninguno |
| 5 | Rascacielos | Remate o torre con el rasgo del negocio | Mojón |

«Solar sin construir» en la interfaz es el nivel 0.

## Reglas

- **El cuerpo no se sustituye nunca.** Cada nivel suma piezas; ninguna resta ni reemplaza el edificio.
- **Cada añadido es un detalle del negocio**, no una planta residencial genérica.
- **El nivel 0 ya se lee como el negocio.** Si hace falta el rótulo para saber qué es, el cuerpo está mal.
- **Cada nivel cambia la silueta o el contraste.** Un añadido que no se ve desde el plano `turn` no cuenta.
- El nivel 5 sigue siendo reconocible como el mismo edificio.

## Marcadores

No se modelan por propiedad. `CityLayout.levelMarkers` coloca un único mojón en el nivel 5, en la franja delantera del solar, con el anillo en el color de la zona.

### Mejoras sobre la isla

Implementadas el 2026-11-06 con las mallas ya subidas (`marker_house`, `marker_hotel` y `marker_tower`), reducidas por código: `CityLayout.islandMarkers` y `ArtAssets.islandMarkers`, colocadas por `BuildingView`. Falta verlas en Studio y la aprobación del responsable; si se ven toscas, se modelan otras. Las propiedades tienen en la calle una isla pintada del lado del edificio, pensada para el sistema clásico de mejoras:

- Niveles 1 a 3: de 1 a 3 casitas. Nivel 4: hotel. Nivel 5: rascacielos, además del mojón.
- Son modelos 3D a escala de ficha: casita de unos 2 studs y rascacielos de hasta 4.
- Primero se prueban las mallas ya subidas, reducidas por código; si se ven toscas, se modelan otras.
- Caliza, acero y oro; nunca casitas verdes ni hotel rojo. Se incluye en la consulta legal.

## Ejemplos

- **Bodega La Reserva y Cine Lux:** las referencias de escala.
- **Barbería Morro y Callejón del Hojalatero:** los primeros hechos con este estándar.

## Enlaces

- [Blueprint](blueprint.md)
- [Checklist de aceptación](aceptacion.md)
