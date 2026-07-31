# Estado

**Fase actual**: Fase 4 completada y verificada de verdad. Las 3 secciones
del informe (`CLAUDE.md`, MCP, 3 acciones) funcionan de punta a punta.
Queda solo la Fase 5 (publicar y probar en máquina limpia) para cumplir el
criterio de terminado de `CLAUDE.md`.

**Qué existe ya**:
- `.claude-plugin/marketplace.json` — marketplace `ahorro-tokens-marketplace`
  con un plugin: `ahorro-tokens` (source `./plugins/ahorro-tokens`).
- `plugins/ahorro-tokens/.claude-plugin/plugin.json` — manifest del plugin,
  v0.1.0.
- `plugins/ahorro-tokens/skills/auditoria-tokens/SKILL.md`, las 3 secciones
  del informe completas:
  1. Localiza `CLAUDE.md` del proyecto donde se invoca (vía `wc -lc`) y
     estima su coste en tokens (caracteres/4).
  2. Ejecuta `claude mcp list` y transcribe su salida literal. Se eligió
     `claude mcp list` en vez de parsear `.mcp.json` a mano porque agrega
     todos los ámbitos (local, proyecto, usuario, conectores de cuenta) sin
     reimplementar esa lógica de precedencia.
  3. Deriva hasta 3 acciones solo de los datos anteriores: revisar
     servidores MCP si hay ≥1 conectado, recortar/mover a skills si
     CLAUDE.md supera 2000 tokens (umbral elegido por mí: es más de lo que
     cabe en una pantalla sin scroll, señal simple de que ha dejado de ser
     reglas cortas), o decir explícitamente que no hay acciones claras si no
     aplica ninguna regla. No rellena con relleno genérico.
- `CLAUDE.md`, `PLAN.md`, este fichero.

**Verificado de verdad (por el usuario, en su máquina)**:
- Fase 1 (texto fijo): confirmada end-to-end.
- Fase 2, caso con `CLAUDE.md` (este proyecto, 35 líneas / 1581 caracteres):
  "~395 tokens estimados (1581 caracteres, 35 líneas)" — aritmética exacta.
- Fase 2, caso sin `CLAUDE.md` (desde `/tmp`): "No se encontró CLAUDE.md en
  este proyecto (0 tokens)", correcto.
- Fase 3, en este proyecto: la sección 2 mostró "claude.ai Dice:
  https://mcp.dice.com/mcp - ✔ Connected", coincidiendo con lo que `claude
  mcp list` reporta (incluye conectores de cuenta, no solo `.mcp.json` del
  proyecto — correcto para el propósito de auditar coste de contexto).
- Fase 4, caso con 1 MCP y CLAUDE.md corto (este proyecto, ~395 tokens):
  solo salió la acción 1 (revisar el servidor MCP), como se esperaba —
  regla 2 no aplicó.
- Fase 4, caso con 1 MCP y CLAUDE.md largo (fixture desechable de prueba,
  8428 caracteres / ~2107 tokens, ya borrado): salieron las acciones 1 y 2,
  y la acción 2 citó procedimientos concretos del propio fichero
  (despliegue de catálogo, rotación de credenciales, gestión de picos de
  tráfico...) en vez de texto genérico. Aritmética exacta: 8428/4 = 2107.

Las 3 secciones están verificadas en al menos dos proyectos con perfiles
distintos, cumpliendo el criterio de la Fase 4 de `PLAN.md`.

**Anomalía conocida (no bloqueante)**: tras editar `SKILL.md`, la primera
invocación puede devolver una versión vieja cacheada; invocar dos veces
antes de dar por buena la salida si se vuelve a tocar el fichero.

**Siguiente acción concreta (Fase 5, última)**:
Crear el repositorio en GitHub para este marketplace y probar la
instalación de verdad: `/plugin marketplace add <owner/repo>` +
`/plugin install ahorro-tokens@ahorro-tokens-marketplace` +
`/ahorro-tokens:auditoria-tokens`, idealmente desde una máquina o contenedor
distinto al que se ha usado para desarrollar. Esto es lo único que falta
para cumplir el criterio de terminado de `CLAUDE.md`. Requiere decisión del
usuario: nombre del repo, visibilidad (público/privado) y si lo crea él o
se le pide a Claude que lo haga con `gh`.
