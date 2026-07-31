# Estado

**Fase actual**: Fase 5 cerrada. v0.1 terminado según el criterio de
`CLAUDE.md`: el plugin se instala desde el repo y `/auditoria-tokens`
devuelve un informe útil.

**Repositorio**: https://github.com/femogo/ahorro-tokens-marketplace
(**público**), rama `main`.

**Decisiones de empaquetado (Fase 5)**:
- `plugin.json` **no fija `version`** a propósito. La documentación avisa de
  que una versión fijada congela a los usuarios ya instalados hasta que se
  sube el número a mano; sin el campo, cada commit cuenta como versión nueva
  y `claude plugin update` recoge los cambios solo. `claude plugin validate`
  emite un warning por esto — es esperado, no un fallo.
- Añadidos `README.md` (instrucciones de instalación, incluida la nota de
  `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`), `LICENSE` (MIT) y metadatos
  `homepage`/`repository`/`license`/`keywords` en `plugin.json`.
- Añadida `description` al marketplace (era un warning de validate).

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

**Fase 5 — publicación y distribución real (verificado, con una salvedad)**:
- `gh` instalado y autenticado como `femogo` (scope `repo`).
- `git init` local (identidad de commit configurada solo a nivel de repo,
  no global), commit `45506dc`, repo privado creado con `gh repo create
  --push`: https://github.com/femogo/ahorro-tokens-marketplace.
- Confirmado con `gh repo view`: `visibility: PRIVATE`, rama por defecto
  `main`.
- Camino real probado de punta a punta, sin `--plugin-dir`:
  `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1 claude plugin marketplace add
  femogo/ahorro-tokens-marketplace` → `✔ Successfully added marketplace`.
  (El shorthand `owner/repo` clona por SSH por defecto y falló por falta de
  host key; la propia documentación indica forzar HTTPS con esa variable de
  entorno. También hizo falta `gh auth setup-git` para el credential
  helper.)
  `claude plugin install ahorro-tokens@ahorro-tokens-marketplace` → `✔
  Successfully installed`.
  `claude -p "/ahorro-tokens:auditoria-tokens"` (ya sin `--plugin-dir`) →
  mismo informe correcto de siempre (395 tokens, 1 MCP conectado, 1 acción).
- **Salvedad**: estas pruebas las ejecuté yo (Claude), en este mismo
  contenedor de desarrollo — no en una máquina distinta. Lo que sí es nuevo:
  es la primera vez que se prueba el mecanismo real de distribución
  (antes todo era `--plugin-dir`), y el caché de marketplace/plugin estaba
  vacío para este marketplace antes de la prueba.

**Ideas para más adelante (nada de esto está comprometido)**:
- Contar tokens de verdad con un tokenizador en vez de caracteres/4.
- Mirar también `.claude/skills/` y ficheros `CLAUDE.md` anidados, que
  también pesan.
- Contar herramientas por servidor MCP, no solo el número de servidores: un
  servidor con 40 herramientas cuesta mucho más que uno con 3.

Cualquiera de estas abre la v0.2 y hay que decidirla antes de tocar código:
la v0.1 está deliberadamente cerrada.
