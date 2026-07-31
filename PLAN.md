# Plan — ahorro-tokens

Fases de lo mínimo a lo completo. Cada una debe cerrarse antes de abrir la
siguiente.

## Fase 0 — Estructura y documentación (hecha)
Marketplace y esqueleto del plugin creados (`marketplace.json`, `plugin.json`
sin componentes todavía), más `CLAUDE.md`, `PLAN.md`, `ESTADO.md`.
**Salida verificable**: los tres ficheros de raíz existen y `plugin.json` /
`marketplace.json` tienen el formato validado contra la documentación oficial.

## Fase 1 — Esqueleto instalable y ejecutable
Añadir `skills/auditoria-tokens/SKILL.md` con `disable-model-invocation: true`
que devuelva un texto fijo (sin análisis real todavía). Nada más.
**Salida verificable**: `claude --plugin-dir ./plugins/ahorro-tokens` +
`/ahorro-tokens:auditoria-tokens` imprime el texto fijo. También:
`claude plugin validate ./plugins/ahorro-tokens` pasa sin errores.

## Fase 2 — Coste en tokens de CLAUDE.md
El comando localiza el CLAUDE.md del proyecto donde se ejecuta y estima su
coste en tokens.
**Salida verificable**: ejecutado sobre 2-3 proyectos con CLAUDE.md de
tamaños distintos, el número estimado es coherente con el tamaño del fichero
(revisión manual, no un test automático).

## Fase 3 — Servidores MCP configurados
El comando detecta y lista los servidores MCP configurados en el proyecto
(`.mcp.json`, settings relevantes).
**Salida verificable**: ejecutado sobre un proyecto con MCP configurado, la
lista mostrada coincide con la configuración real.

## Fase 4 — Las 3 acciones de ahorro
El comando combina lo anterior en heurísticas concretas (p. ej. CLAUDE.md
demasiado largo, MCP con muchas herramientas no usadas) y devuelve las 3
acciones más impactantes.
**Salida verificable**: probado en al menos 2 proyectos reales distintos,
las 3 acciones sugeridas son específicas y accionables, no genéricas.

## Fase 5 — Publicación y prueba en máquina limpia
Subir el repo a GitHub, comprobar `/plugin marketplace add` +
`/plugin install` desde una máquina/contenedor limpio.
**Salida verificable**: cumple el criterio de terminado de `CLAUDE.md` sin
retoques manuales adicionales.
