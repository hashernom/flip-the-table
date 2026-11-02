# Subfase 01: Cimientos. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar listo un repositorio con herramientas fijadas, pruebas sin Studio, azar determinista y los datos de la partida.

**Architecture:** Código Luau sincronizado con Rojo. La lógica pura se prueba con Lune y un arnés propio. Ver [arquitectura](../01-arquitectura/arquitectura.md).

**Tech Stack:** Luau, Rojo 7, Rokit, Lune, Selene, StyLua, luau-lsp.

**Spec:** [ficha](../00-ficha/ficha-propuesta.md) y [ficha del MVP](ficha-mvp.md).

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** son 5 tareas cortas y seguidas, con poca lógica. Un subagente y un revisor por tarea costarían más de lo que aportan; basta una revisión final, porque cualquier error de herramientas aparece al instante.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Este plan crea el repositorio: no hay rama previa. El primer commit incluye `docs/` y `CLAUDE.md`.
- Requiere Rokit instalado; si falta, pide permiso antes de instalarlo.
- Solo se necesita Studio para comparar `Rng` en la Tarea 3. Si no está abierto, pide al responsable que lo abra.
- Termina cuando `lune run tools/check` da código 0 y el revisor aprueba la rama.

## Global Constraints

- `src/shared/rules` no usa `game`, `workspace`, `Instance`, `task` ni `Random`.
- Todo número ajustable vive en `src/shared/config`.
- Require por cadena relativa; sin módulos `init` en `src/shared/rules`.
- Antes de hacer push, los agentes se detienen y preguntan.

## Review Focus

1. Una misma semilla da siempre la misma partida, en Lune y en Roblox. Prueba en Tarea 3.
2. Un fallo en una prueba hace que el comando termine con código distinto de 0. Prueba en Tarea 2.
3. Los tableros suman exactamente 32, 40 y 48 casillas. Prueba en Tarea 4.
4. Un número fuera de rango en `Rng.int` falla de forma clara, sin bucle infinito. Prueba en Tarea 3.
5. La lógica pura no puede importar APIs de Roblox por descuido. Prueba en Tarea 5.

---

### Task 1: Repositorio y herramientas

**Módulos:** configuración del proyecto.

**Archivos:**
- Crear: `.gitignore`, `rokit.toml`, `default.project.json`, `selene.toml`, `stylua.toml`
- Crear: `src/shared/.gitkeep`, `src/server/.gitkeep`, `src/client/.gitkeep`

**Interfaces:**
- Produce: `src/shared` en `ReplicatedStorage.Shared`, `src/server` en `ServerScriptService.Server`, `src/client` en `StarterPlayer.StarterPlayerScripts.Client`.

**Criterios de aceptación:**
- [x] `rojo build -o build/game.rbxl` genera el archivo sin errores.
- [x] `rokit.toml` fija la versión exacta de cada herramienta.
- [x] `build/` queda ignorado por git.

- [x] **Paso 1:** Ejecutar `git init` en la raíz; crear los archivos.
- [x] **Paso 2:** Ejecutar `rokit add rojo-rbx/rojo`, `rokit add lune-org/lune`, `rokit add Kampfkarren/selene`, `rokit add JohnnyMorganz/StyLua` y `rokit add JohnnyMorganz/luau-lsp`.
- [x] **Paso 3:** Ejecutar `rojo build -o build/game.rbxl`. Esperado: archivo creado y código de salida 0.
- [x] **Paso 4:** Hacer commit, con `docs/` y `CLAUDE.md` incluidos: `chore: configurar repositorio y herramientas`.

### Task 2: Arnés de pruebas

**Módulos:** `tests/harness`, `tests/run`.

**Archivos:**
- Crear: `tests/harness.luau`, `tests/run.luau`, `tests/harness.spec.luau`

**Interfaces:**
- Produce: `describe(name: string, fn: () -> ())`, `it(name: string, fn: () -> ())`, `expect(value).toBe(other)`, `.toEqual(other)` (profunda), `.toThrow()`, `.toBeTruthy()`.
- Produce: `lune run tests/run [filtro]`, que ejecuta `tests/**/*.spec.luau` y termina con 1 si algo falla.

**Criterios de aceptación:**
- [x] Una prueba correcta da código de salida 0.
- [x] Una prueba fallida da código de salida 1 y muestra su nombre.
- [x] El filtro ejecuta solo los archivos cuyo nombre lo contiene.

- [x] **Paso 1: Escribir la prueba**

```luau
describe("expect", function()
    it("compara tablas en profundidad", function()
        expect({ a = { 1, 2 } }).toEqual({ a = { 1, 2 } })
    end)
    it("detecta errores lanzados", function()
        expect(function() error("x") end).toThrow()
    end)
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run harness`. Esperado: falla porque aún no existe el arnés.
- [x] **Paso 3:** Implementar `tests/harness.luau` y `tests/run.luau`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS, código 0.
- [x] **Paso 5:** Añadir temporalmente `expect(1).toBe(2)` y comprobar que el código es 1; retirarlo.
- [x] **Paso 6:** Hacer commit: `test: añadir arnés de pruebas con Lune`.

### Task 3: Azar determinista

**Módulos:** `rules/Rng`.

**Archivos:**
- Crear: `src/shared/rules/Rng.luau`, `tests/rules/Rng.spec.luau`

**Interfaces:**
- Produce: `export type RngState = { seed: number, forced: { number }? }`
- Produce: `Rng.new(seed: number): RngState`, `Rng.int(rng: RngState, min: number, max: number): number`, `Rng.pick<T>(rng: RngState, list: { T }): T`, `Rng.shuffle<T>(rng: RngState, list: { T }): { T }`, `Rng.force(rng: RngState, values: { number })`.

**Criterios de aceptación:**
- [x] Misma semilla, misma secuencia.
- [x] El estado es una tabla simple, serializable.
- [x] `Rng.force` permite fijar los dados en las pruebas.
- [x] `Rng.int` con `min > max` lanza un error claro.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("repite la secuencia con la misma semilla", function()
    local a, b = Rng.new(42), Rng.new(42)
    for _ = 1, 100 do expect(Rng.int(a, 1, 6)).toBe(Rng.int(b, 1, 6)) end
end)
it("respeta el rango", function()
    local r = Rng.new(1)
    for _ = 1, 1000 do
        local v = Rng.int(r, 1, 6)
        expect(v >= 1 and v <= 6).toBeTruthy()
    end
end)
it("usa primero los valores forzados", function()
    local r = Rng.new(1); Rng.force(r, { 3, 4 })
    expect(Rng.int(r, 1, 6)).toBe(3); expect(Rng.int(r, 1, 6)).toBe(4)
end)
it("rechaza un rango invertido", function()
    expect(function() Rng.int(Rng.new(1), 6, 1) end).toThrow()
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run Rng`. Esperado: FAIL.
- [x] **Paso 3:** Implementar con un generador congruencial: `seed = (seed * 1103515245 + 12345) % 2^31`; usar los bits altos para el rango.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Ejecutar el módulo en Studio con `execute_luau` del MCP de Roblox y comparar los 10 primeros valores de la semilla 42 con los de Lune. Esperado: iguales.
- [x] **Paso 6:** Hacer commit: `feat: añadir azar determinista`.

### Task 4: Tipos y datos base

**Módulos:** `rules/Types`, `config/Economy`, `config/Boards`.

**Archivos:**
- Crear: `src/shared/rules/Types.luau`, `src/shared/config/Economy.luau`, `src/shared/config/Boards.luau`, `tests/config/Boards.spec.luau`

**Interfaces:**
- Produce: los tipos de [arquitectura](../01-arquitectura/arquitectura.md), más `Square = { index: number, kind: SquareKind, zoneId: string?, barrioId: string, price: number? }`, `Board = { sizeId: SizeId, squares: { Square }, zones: { [string]: { number } } }`, `PropertyState = { ownerId: PlayerId?, level: number }`, `Pact`, `Modifier`, `MatchStats`, `PlayerView`.
- Produce: `SquareKind = "Start" | "Property" | "Spin" | "Market" | "Duel" | "Portal" | "Billboard" | "Tribunal" | "Tax"`.
- Produce: `Boards.forPlayerCount(n: number): SizeId`, `Boards.get(sizeId: SizeId): Board`, `Economy` con los valores de la arquitectura.

**Criterios de aceptación:**
- [x] Los tres tableros cumplen la tabla de composición de la arquitectura.
- [x] La casilla 1 siempre es `Start`.
- [x] Toda zona tiene 3 propiedades y su precio crece a lo largo de la ruta, de 60 a 400.
- [x] El tablero S es un prefijo lógico de los barrios: M y L añaden Puerto y Zona Alta sin renombrar zonas de Centro.

- [x] **Paso 1: Escribir las pruebas**

```luau
local expected = {
    S = { total = 32, Property = 18, Spin = 4, Market = 2, Duel = 2, Portal = 2, Billboard = 1, Tribunal = 1, Tax = 1 },
    M = { total = 40, Property = 24, Spin = 5, Market = 2, Duel = 2, Portal = 2, Billboard = 2, Tribunal = 1, Tax = 1 },
    L = { total = 48, Property = 30, Spin = 6, Market = 2, Duel = 3, Portal = 3, Billboard = 1, Tribunal = 1, Tax = 1 },
}
-- Para cada tamaño: contar casillas por tipo y comparar con expected.
it("elige el tamaño según los jugadores", function()
    expect(Boards.forPlayerCount(2)).toBe("S"); expect(Boards.forPlayerCount(4)).toBe("S")
    expect(Boards.forPlayerCount(5)).toBe("M"); expect(Boards.forPlayerCount(6)).toBe("M")
    expect(Boards.forPlayerCount(7)).toBe("L"); expect(Boards.forPlayerCount(8)).toBe("L")
    expect(function() Boards.forPlayerCount(9) end).toThrow()
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run Boards`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los tipos y los datos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: añadir tipos y datos de tablero`.

### Task 5: Comprobación global

**Módulos:** `tools/check`.

**Archivos:**
- Crear: `tools/check.luau`, `tests/tools/check.spec.luau`

**Interfaces:**
- Produce: `lune run tools/check`, que ejecuta StyLua en modo comprobación, Selene, `luau-lsp analyze`, las pruebas y `pureRules(paths): { string }`.
- Produce: `pureRules` devuelve los archivos de `src/shared/rules` que mencionan `game.`, `workspace`, `Instance.`, `task.` o `Random.`.

**Criterios de aceptación:**
- [x] Un archivo de `rules` con `workspace` hace fallar la comprobación y se nombra.
- [x] Sin problemas, el comando termina con código 0.

- [x] **Paso 1:** Escribir la prueba: `pureRules` con un archivo de ejemplo que contiene `workspace.Gravity` lo devuelve; con `Rng.luau`, devuelve una lista vacía.
- [x] **Paso 2:** Ejecutar `lune run tests/run check`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `tools/check.luau`.
- [x] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [x] **Paso 5:** Hacer commit: `chore: añadir comprobación global`.
