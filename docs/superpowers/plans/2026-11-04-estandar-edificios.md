# Estándar de edificación Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir la guía de estilo y publicar el estándar de edificación con la ficha de Cobre como piloto.

**Architecture:** Solo documentación. La guía queda como fuente de identidad; `art/edificios/` concentra reglas, niveles, checklist e índice; cada zona tiene su ficha y Cobre es el piloto de 2 propiedades.

**Tech Stack:** Markdown, PowerShell, Lune, git.

**Spec:** `docs/superpowers/specs/2026-11-04-estandar-edificios-design.md`

## Global Constraints

- 12 zonas y 34 propiedades; Cobre y Violeta tienen **2** propiedades, el resto 3.
- Nombres y colores de `src/shared/config/Strings.luau`; precios y casillas de `src/shared/config/Boards.luau`.
- Solar 36 × 22; huella 32 × 18; altura final ≤ 92; bandas: Centro 28–88, Puerto 14–32, Zona Alta 56–92, Industrial 14–46.
- Propiedad completa ≤ 10 000 tris; LOD1 ≤ 50 %; ≤ 3 materiales; 1 unidad Blender = 1 stud.
- Rótulo con placa + `SurfaceGui` desde `Strings`; placa de dueño creada por código.
- Español; sin marca ajena, casino, neón ni verde de fieltro.

## Review Focus

1. **Zonas de 2 propiedades:** Cobre y Violeta no pueden tener una tercera ficha; la plantilla debe decir «2 o 3».
2. **Alturas:** una propiedad de 4 plantas en Centro (28) más +8 no puede pasar de 92; Zona Alta se queda en 8–13 plantas.
3. **Nombres largos:** «Fábrica de Ladrillos La Hormiga» no cabe en dos líneas; la ficha debe fijar forma corta.
4. **Colores de zona:** la tabla de la guía debe coincidir exactamente con `Strings.luau`; un hex distinto rompe la identidad.
5. **Contradicciones viejas:** «10 zonas», «los tres barrios», «18 × 22» y «Pendiente de alinear» deben desaparecer.

---

### Task 1: Corregir la guía de estilo

**Files:**
- Modify: `art/guia-de-estilo.md`

**Interfaces:**
- Consumes: nombres y colores de `src/shared/config/Strings.luau`; barrios de `src/shared/config/Boards.luau`.
- Produces: tabla de 12 zonas, 4 barrios, solar 36 × 22 y enlace a `art/edificios/README.md`.

- [ ] **Step 1: Sustituir la tabla de zonas de §2.3 por las 12 reales**

Cada fila: número, nombre completo, hex de `Strings`, símbolo de la propuesta y barrio. Cobre, Cian, Magenta, Naranja, Carmesí y Limón en Centro; Esmeralda y Violeta en Puerto; Añil y Blanca en Zona Alta; Grafito y Ocre en Industrial.

- [ ] **Step 2: Reescribir §7 con los 4 barrios**

Centro 4–12 plantas, Puerto 2–4, Zona Alta 8–13, Industrial 2–6 con chimeneas hasta 60. Añadir la frase de que el diseño por edificio vive en `art/edificios/`.

- [ ] **Step 3: Corregir §8**

Sustituir «solar 18 × 22» por «solar 36 × 22 (provisional)».

- [ ] **Step 4: Retirar el aviso obsoleto de §5.1**

Sustituir «Pendiente de alinear» por la nota de que la escalera está alineada desde el 2026-11-04 y que los marcadores los genera el código.

- [ ] **Step 5: Actualizar §10**

Añadir el pendiente del estándar de edificación y mantener los dos que siguen abiertos.

- [ ] **Step 6: Verificar**

Run:
```powershell
Select-String -Path art\guia-de-estilo.md -Pattern '20.30 plantas|18 . 22|Pendiente de alinear|Los tres tienen'
```
Expected: sin coincidencias. Después, contar las filas de la tabla de zonas: 12.

- [ ] **Step 7: Commit**

```powershell
git add art/guia-de-estilo.md
git commit -m "docs: alinear la guia de estilo con las 12 zonas y la escala real"
```

### Task 2: Crear el índice y las reglas comunes

**Files:**
- Create: `art/edificios/README.md`

**Interfaces:**
- Consumes: spec §6 y §7; guía corregida.
- Produces: reglas comunes, plantillas de zona y propiedad, índice de las 12 zonas y glosario.

- [ ] **Step 1: Escribir el README**

Secciones: propósito y autoridad, índice de 12 zonas con estado (`Cobre` enlaza a su ficha; el resto, pendiente), reglas comunes (solar, huella, alturas, materiales, presupuesto, rótulo, placa, añadidos, cámara), plantilla de zona, plantilla de propiedad y glosario.

- [ ] **Step 2: Verificar**

Run:
```powershell
Test-Path art\edificios\README.md
Select-String -Path art\edificios\README.md -Pattern '36 . 22','10 000','SignAnchor','PlaqueAnchor','2 o 3'
```
Expected: `True` y las cinco coincidencias.

- [ ] **Step 3: Commit**

```powershell
git add art/edificios/README.md
git commit -m "docs: anadir el indice y las reglas del estandar de edificios"
```

### Task 3: Crear el contrato de niveles

**Files:**
- Create: `art/edificios/niveles.md`

**Interfaces:**
- Consumes: spec §6.2 y §6.7.
- Produces: semántica de los niveles 0–5, incrementos, nombres de piezas y regla de marcadores.

- [ ] **Step 1: Escribir el contrato**

Tabla de niveles con qué añade cada uno y sus studs; fórmula del cuerpo; nombres `<id>-body` y `<id>-addon1..5`; marcadores generados por `CityLayout.levelMarkers`; presupuesto y LOD.

- [ ] **Step 2: Verificar**

Run:
```powershell
Select-String -Path art\edificios\niveles.md -Pattern 'addon1','levelMarkers','\+20','92'
```
Expected: las cuatro coincidencias.

- [ ] **Step 3: Commit**

```powershell
git add art/edificios/niveles.md
git commit -m "docs: definir el contrato de los cinco niveles"
```

### Task 4: Crear el checklist de aceptación

**Files:**
- Create: `art/edificios/aceptacion.md`

**Interfaces:**
- Consumes: spec §8.
- Produces: checklist técnico, visual y de aprobación, y procedimiento de cámara.

- [ ] **Step 1: Escribir el checklist**

Tres bloques (técnico, visual, aprobación), la prueba de cámara con el plano `turn` y las capturas exigidas.

- [ ] **Step 2: Verificar**

Run:
```powershell
Select-String -Path art\edificios\aceptacion.md -Pattern 'SignAnchor','PlaqueAnchor','raycast','approvedBy'
```
Expected: las cuatro coincidencias.

- [ ] **Step 3: Commit**

```powershell
git add art/edificios/aceptacion.md
git commit -m "docs: anadir el checklist de aceptacion de edificios"
```

### Task 5: Escribir la ficha de Cobre (piloto)

**Files:**
- Create: `art/edificios/zonas/01-cobre.md`

**Interfaces:**
- Consumes: `Strings.luau` (Cobre), `Boards.luau` (casillas 2–3, precio 60), plantilla del README.
- Produces: ficha de zona con 2 propiedades y 5 añadidos por propiedad.

- [ ] **Step 1: Escribir la cabecera y el carácter de la zona**

Cobre, Centro, `#C97B3A`, símbolo moneda, 60/60/60, casillas 2–3 en S/M/L.

- [ ] **Step 2: Escribir las dos fichas**

Barbería Morro y Callejón del Hojalatero, cada una con los 11 campos y sus 5 añadidos. Cobre tiene **2** propiedades, no 3.

- [ ] **Step 3: Verificar**

Run:
```powershell
Select-String -Path art\edificios\zonas\01-cobre.md -Pattern '^### '
lune run tests/run Strings
```
Expected: dos fichas de propiedad; Strings sigue en 14 pruebas.

- [ ] **Step 4: Commit**

```powershell
git add art/edificios/zonas/01-cobre.md
git commit -m "docs: anadir la ficha piloto de Cobre"
```

### Task 6: Enlazar el estándar en ESTADO y PIPELINE

**Files:**
- Modify: `art/ESTADO.md`
- Modify: `art/PIPELINE.md`

**Interfaces:**
- Consumes: `art/edificios/README.md`.
- Produces: enlaces desde los dos documentos de referencia.

- [ ] **Step 1: Actualizar ESTADO**

Añadir el estándar a «Lo que falta» y a «Cómo retomar», con enlace a `art/edificios/README.md`.

- [ ] **Step 2: Actualizar PIPELINE**

Añadir en §3 o §8 el enlace al checklist de aceptación.

- [ ] **Step 3: Verificar**

Run:
```powershell
Select-String -Path art\ESTADO.md,art\PIPELINE.md -Pattern 'edificios/README|edificios/aceptacion'
```
Expected: al menos dos coincidencias.

- [ ] **Step 4: Commit**

```powershell
git add art/ESTADO.md art/PIPELINE.md
git commit -m "docs: enlazar el estandar de edificios desde estado y pipeline"
```

### Task 7: Revisión final del estándar

**Files:**
- Verify: `art/guia-de-estilo.md`, `art/edificios/*`

- [ ] **Step 1: Comprobar enlaces relativos**

Run un script de PowerShell que lea los `](...)` de los archivos nuevos y compruebe que cada ruta existe.

- [ ] **Step 2: Comprobar contradicciones**

Run:
```powershell
Select-String -Path art\guia-de-estilo.md,art\edificios\*.md,art\edificios\zonas\*.md -Pattern '10 zonas|tres barrios|18 . 22|Pendiente de alinear'
```
Expected: sin coincidencias.

- [ ] **Step 3: Comprobar que no se tocó código**

Run:
```powershell
git status --porcelain=v1
lune run tests/run Strings
```
Expected: solo los archivos de documentación previstos; 14 pruebas en Strings.

- [ ] **Step 4: Commit final si queda algo**

```powershell
git add art/edificios art/guia-de-estilo.md art/ESTADO.md art/PIPELINE.md
git commit -m "docs: cerrar el estandar de edificacion y su piloto"
```
