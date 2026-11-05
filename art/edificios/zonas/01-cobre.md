# Cobre — Callejón del Cobre

**Zona:** Callejón del Cobre · **Barrio:** Centro · **Color:** cobre · **Símbolo:** moneda
**Propiedades:** dos · **Estado:** Aprobada (2026-11-05); los modelos aprobados mandan sobre lo que aquí se describa

## Carácter

No es un barrio residencial: **cada edificio es su negocio**. La barbería ocupa toda la fachada con su escaparate, su poste y su rótulo; el taller de hojalata enseña la chapa, la chimenea y las planchas. El ladrillo y la caliza son el fondo; el cobre, el acento. Ninguna de las dos es un bloque de viviendas con un local abajo.

## Alturas

Edificios bajos: cuerpo de 14 en la barbería y de 17 en el taller. Las medidas las fija [el blueprint](../blueprint.md). Cobre se queda en la parte baja a propósito: la barbería y el taller compiten en fachada, no en altura.

## Materiales

Ladrillo, caliza, acero, cristal, lona, pizarra y metal teñido de cobre. Cada malla lleva un material principal; no se inventa ninguno.

## Kit compartido

Solo el fondo común; la fachada de cada propiedad es distinta.

- Cornisa de caliza.
- Pilastra de ladrillo en las esquinas.
- Banda de cobre como acento, nunca en superficies grandes.
- Marco metálico para puertas y ventanas.
- Canalón de cobre.

---

## Barbería Morro

**1. Nombre y uso.** Barbería con academia de barberos. Las plantas altas son salón y academia, no viviendas.

**2. Concepto.** Edificio de barbería: escaparate alto, poste vertical en la puerta, toldo a rayas y marco de rótulo en la cubierta. Se reconoce por el poste y el escaparate, no por el color.

**3. Masa.** Cuatro plantas; la baja a la altura de la calle; cubierta plana con marco de rótulo y tanque; cornisa de caliza con dentículos.

**4. Materiales.** Caliza y ladrillo, con cristal, acero, lona y cobre.

**5. Fachada.** Escaparate alto y puerta a la altura del avatar; poste entre escaparate y puerta; toldo a rayas. Plantas altas con ventanales de academia y recercado de caliza; rótulo vertical pintado entre ventanales; cornisa y canalón de cobre.

**6. Rótulo.** Placa de caliza sobre la puerta y el toldo; «BARBERÍA MORRO» en Oswald, asfalto sobre caliza, borde del color de la zona. `SignAnchor` en el centro de la placa, mirando a la calle. El texto lo pone el cliente; el marco de cubierta lleva después el rótulo de la academia.

**7. Silueta.** Poste de barbero, marco de rótulo en la cubierta y tanque de agua. El poste es el elemento único.

**8. Placa de dueño.** A la derecha de la puerta; `PlaqueAnchor`. La placa la crea el código.

**9. Los cinco añadidos.**
1. Toldo de lona a rayas y banda de azulejo.
2. Vitrina de productos y escaparate alto con carpintería de acero.
3. Mirador de la academia con barandilla y toldo.
4. Pabellón de hotel retranqueado, con dos filas de ventanas, caliza y toldos a rayas.
5. Torre de rótulo de acero con poste de barbero gigante y remate de cobre.

**10. Cámara.** Probar con el plano `turn`; la altura no es el riesgo.

**11. Notas técnicas.** Presupuesto del estándar; LOD1 estanca; materiales de la biblioteca. La lona entra con el primer añadido; el cuerpo no la lleva.

---

## Callejón del Hojalatero

**1. Nombre y uso.** Taller de hojalatería y almacén de chapa. Las plantas altas son almacén y taller de grabado, no viviendas.

**2. Concepto.** Nave de taller con portalón, fachada de chapa ondulada, chimenea y planchas colgadas. Se reconoce por la chimenea y las planchas; no compite con el poste de la barbería.

**3. Masa.** Cuatro plantas; la baja a la altura de la calle; cubierta inclinada de pizarra con chimenea; base de caliza.

**4. Materiales.** Ladrillo y acero, con pizarra, caliza y cristal; la chapa ondulada entra con el primer añadido.

**5. Fachada.** Portalón a la altura del avatar con marco metálico; toldo de chapa ondulada; ventanas industriales; planchas de hojalata colgadas entre las ventanas; viga de carga sobre el portalón.

**6. Rótulo.** Placa de caliza sobre el portalón y el toldo; «CALLEJÓN DEL / HOJALATERO» en dos líneas, Oswald, asfalto sobre caliza, borde del color de la zona. `SignAnchor` en el centro.

**7. Silueta.** Chimenea metálica en la cubierta, planchas colgadas y viga de carga. La chimenea es el elemento único.

**8. Placa de dueño.** A la derecha del portalón; `PlaqueAnchor`.

**9. Los cinco añadidos.**
1. Toldo de chapa ondulada y canalón de cobre.
2. Portalón ampliado, más planchas y viga de carga reforzada.
3. Chimenea alta, silo de chapa y parche de pizarra.
4. Nave anexa de hotel retranqueada, con chapa y banda de caliza.
5. Torre de celosía de acero con remate de cobre.

**10. Cámara.** Probar con el plano `turn`; la altura no es el riesgo.

**11. Notas técnicas.** Presupuesto del estándar; LOD1 estanca; materiales de la biblioteca. Las planchas lisas de acero van en el cuerpo porque definen su silueta; la pizarra ya está en el cuerpo.

---

## Notas de la prueba

La prueba de Cobre enseñó tres cosas: las puertas van a la altura del avatar y la planta baja es una planta completa; el rótulo va por encima de la puerta y del toldo; y la LOD1 también tiene que ser estanca. Los modelos de la prueba anterior quedan obsoletos.

## Referencias

- Recorte de `art/identidad/concepto-centro.png`: la crujía de ladrillo y caliza con toldos.
- [Guía de estilo](../../guia-de-estilo.md) · [Niveles](../niveles.md) · [Aceptación](../aceptacion.md)
- Sin fotos externas en el repositorio: las referencias reales son barberías con academia y talleres de hojalata de calle estrecha.

## Notas de zona

- Cobre es la zona piloto. Las otras once fichas se escriben después de aprobar esta.
- El símbolo de la moneda aún no está implementado en el cliente; se pinta en la casilla y en la tarjeta cuando exista.
- Nada de neón, casino ni marcas; el cobre es un acento, no una superficie.
- Las dos propiedades no pueden leerse como el mismo edificio: una es escaparate, poste y academia; la otra, portalón, chapa y chimenea.
