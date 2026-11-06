---
version: 1
slug: "src-client-ui-trademenu-luau"
primary_target: "src/client/ui/TradeMenu.luau"
related_targets: ["src/client/ui/PactMenu.luau","src/client/ui/TokenMenu.luau","src/client/ui/RematchMenu.luau","src/client/ui/Overview.luau","src/client/ui/Components.luau"]
---

Modo: Operate. Superficie: el estándar de ventana emergente de la partida (Tratos para proponer y para responder, Pactos, Elegir ficha, Revancha y, en pequeño, la vista general). Primera pieza: `src/client/ui/TradeMenu.luau`.

Público y tarea: de 2 a 8 amigos en una partida de mesa. Cualquiera tiene que entender en segundos qué hace la ventana, cómo se usa y qué está eligiendo, sin que nadie se lo explique por voz.

Decidido por el responsable (2026-11-05): maqueta «Valla de obra» sin los largueros rayados; escrituras como piezas del trato con dinero libre (cartas de mano fuera); explicación con una frase fija y «Cómo funciona» desplegable en 2 o 3 pasos, igual en todas las ventanas. Lo ocupado o elegido cambia de forma y tono, no solo de texto.

## Direction contract

THESIS: Cada ventana es un tablón de obra con carteles pegados: una pieza física, no una caja plana con botones en lista. Rechaza el modal gris y la hoja centrada sin materia.

OWN-WORLD: Tablón de asfalto con borde de caliza y dos postes de acero a los lados. Encima, carteles de papel caliza, ligeramente torcidos, sujetos con cinta. Escrituras en miniatura, sello rojo torcido para lo elegido, disco con aro del asiento y taxímetro. Un solo amarillo: el botón principal.

STORY: Arriba, el cartel del título dice qué es y cómo se usa. Debajo, un cartel por jugador con sus escrituras y su dinero; una señal de doble sentido entre ellos. Abajo, el resumen y el verbo amarillo.

FIRST VIEWPORT: A 1440x900, tablón de unos 1200x820 centrado. Cartel de título a lo ancho con Cerrar y Esc; dos carteles de 500 con perfil, tres escrituras y campo de dinero; señal marina de doble sentido en medio; resumen y ENVIAR al pie.

FORM: Estructura 6 de mi lista, «valla de obra». Firma: lo elegido se despega del cartel con su sello rojo. seed:1e2ff1aa

FINISH: sin revisión ni documentación no está terminado; acaba con la revisión final, el veredicto y DESIGN.md actualizado.
