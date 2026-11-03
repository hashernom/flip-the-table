# Texturas CC0

Sets descargados de [ambientCG](https://ambientcg.com). Licencia **CC0**: uso comercial libre, sin
atribución obligatoria. Se acredita igualmente por trazabilidad.

| Set local | Asset ambientCG | Fecha |
| --- | --- | --- |
| `brick_red_*` | `Bricks097` | 2026-11-02 |
| `brick_warm_*` | `Bricks042` | 2026-11-02 |
| `concrete_*` | `Concrete034` | 2026-11-02 |
| `asphalt_*` | `Asphalt012` | 2026-11-02 |

`Bricks075A` se descartó: es sillería rústica y parecía roca. `Bricks097` es ladrillo rojo
desgastado y `Bricks042` ladrillo cálido, los dos con junta regular, que es lo que pide Manhattan.

Cada set trae `_color` (albedo), `_normal` (NormalGL, el formato OpenGL que Roblox exige) y
`_roughness` (gris). Los originales son JPG de 1K, que es el tamaño que usa el juego.

**Si se cambia un set**, se sustituyen los tres archivos con el mismo nombre y se vuelven a subir:
los ids viven en `art/asset-ids.json`.

Para regenerar la descarga: `art/generators/fetch_cc0.ps1`.
