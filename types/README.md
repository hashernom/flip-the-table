# Definiciones de tipos de Roblox

`globalTypes.d.lua` son las definiciones de la API de Roblox que `luau-lsp` necesita para analizar
`src/server` y `src/client` con `--platform=roblox`. No es código del juego: es un archivo de datos
generado a partir del volcado de la API de Roblox y no se edita a mano.

## Procedencia

- Origen: [`JohnnyMorganz/luau-lsp`](https://github.com/JohnnyMorganz/luau-lsp), ruta
  `scripts/globalTypes.d.lua`.
- Commit exacto: `f8cc4b9b797b48df5b895bbaf85b0faf9eac5e67`.
- URL de descarga:
  `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/f8cc4b9b797b48df5b895bbaf85b0faf9eac5e67/scripts/globalTypes.d.lua`
- Tamaño: 876 505 bytes.
- SHA-256 del archivo: `A952DCDDB0EFBFBCA5BC08F48E2C2C95EA89491A55EA012612B96625112F7E57`.
- Fecha de descarga: 2026-11-02.

Está versionado porque `luau-lsp` no descarga definiciones por su cuenta. Sin el archivo, el pase de
`tools/check` sobre el servidor dependería de la red y de la versión de la API publicada ese día.

## Cómo se usa

`tools/check` genera `sourcemap.json` con Rojo y ejecuta un segundo pase:

```
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --platform=roblox --definitions=types/globalTypes.d.lua --sourcemap=sourcemap.json <carpetas>
```

Las carpetas son `src/server` y `src/client`, filtradas a las que contienen al menos un `.luau`.
`src/client` está vacío hasta el plan 05 y `luau-lsp` sale con código 1 si una ruta no aporta
ficheros. `sourcemap.json` está en `.gitignore`; este archivo, no.

El sourcemap funciona porque `default.project.json` monta `src/shared` como **`shared` en
minúsculas** bajo `ServerScriptService` y bajo `StarterPlayer.StarterPlayerScripts`, además de
`ReplicatedStorage.Shared` (R-P17). Así la misma ruta relativa `../../shared/...` resuelve igual en
disco (Lune), en el DataModel del servidor (`ServerScriptService.shared...`) y en el del cliente
(`StarterPlayerScripts.shared...`). Sin ese montaje, `luau-lsp` busca
`game/ServerScriptService/shared/...` y falla, porque una ruta relativa no cruza de servicio.
`lobby.project.json` (Tarea 5) tiene que repetir el mismo montaje.

El pase estándar para `src/shared`, `tests` y `tools` no cambia y sigue siendo el que impide usar
globales de Roblox en el motor.

`types/` queda fuera de StyLua y Selene, que solo recorren `src`, `tests` y `tools`.

## Cómo refrescarlo

1. Elegir un commit de `JohnnyMorganz/luau-lsp`, idealmente el que corresponda a la versión fijada
   en `rokit.toml`.
2. Descargar y comprobar tamaño, SHA-256 y que el archivo empieza por `--#METADATA#`:

   ```powershell
   curl.exe -L "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/<commit>/scripts/globalTypes.d.lua" -o types/globalTypes.d.lua
   (Get-Item types/globalTypes.d.lua).Length
   (Get-FileHash types/globalTypes.d.lua -Algorithm SHA256).Hash
   ```

3. Actualizar el commit, el tamaño y el SHA-256 de este documento.
4. Ejecutar el pase de la sección anterior y el resto de `lune run tools/check`.
5. Commitear el archivo y este README juntos.
