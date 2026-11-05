# Aceptación de una propiedad

Lista comprobable para aprobar una propiedad modelada. Es la fase D de [blueprint.md](blueprint.md), donde están las medidas.

## Evidencia

- Una entrada en `art/manifest.json` por propiedad, categoría `Building`, con las piezas en `assetIds`.
- Estado `InGame` antes de pedir la aprobación.
- Tres capturas **en el juego**: calle, plano de turno y vista general. Una imagen de Blender no vale.
- Al aprobar: `Approved`, `approvedBy` y la fecha. Solo lo aprueba el responsable.

## Checklist técnico

- [ ] Cada FBX contiene una sola malla, con un material y un color.
- [ ] Triángulos y LOD1 dentro del presupuesto del blueprint.
- [ ] Origen en el centro de la base, frente hacia -Y; 1 unidad = 1 stud.
- [ ] Materiales de la lista del blueprint.
- [ ] Vuelos delanteros dentro del límite; nada invade la acera.
- [ ] Puerta claramente más alta que el avatar.
- [ ] Cuerpo más 5 añadidos; ningún añadido sustituye al cuerpo.
- [ ] Sin avisos de `ArtLoader` y sin bloque gris en la casilla.

## Checklist visual

- [ ] Se reconoce desde el plano `turn`, sin leer el rótulo.
- [ ] No hay viviendas genéricas ni bloque con un local abajo.
- [ ] La silueta es distinta de las dos propiedades vecinas.
- [ ] A escala junto al avatar y al taxi.
- [ ] El nivel 5 se reconoce como el mismo edificio.
- [ ] Sin marca ajena, casino ni neón.
- [ ] Sin bandas negras ni caras raras.

## Cámara

1. Pon la zona al nivel 5.
2. Para cada casilla de la zona y las dos vecinas, usa el plano `turn` de `CameraShots`.
3. Lanza un raycast de la cámara al punto de mira: no puede tocar ningún edificio.
4. Captura desde cada casilla y desde la vista general: todo visible y nada flotando.

## Niveles

- [ ] Los seis estados se encienden sin huecos ni piezas flotantes.
- [ ] El cuerpo es idéntico en los seis.
- [ ] El mojón sale solo en el nivel 5.

## Rechazo

Se rechaza si incumple un punto técnico, si el edificio no se reconoce desde la calle, si tapa una cámara o si parece una marca existente. El rechazo se anota en la ficha con el motivo.

## Enlaces

- [Blueprint](blueprint.md)
- [Niveles](niveles.md)
