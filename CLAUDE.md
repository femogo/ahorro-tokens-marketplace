# ahorro-tokens

## Objetivo
Plugin de Claude Code, distribuido vía marketplace propio en GitHub, que expone
`/auditoria-tokens`: audita el coste en tokens de un proyecto (CLAUDE.md,
servidores MCP configurados) y devuelve las 3 acciones que más lo reducirían.

## Alcance v0.1
Solo `/auditoria-tokens`. Ningún otro comando, hook, MCP server ni skill
autocargada.

## Reglas
- Todo en castellano: código, commits, documentación, salida del comando.
- La documentación oficial de Claude Code
  (code.claude.com/docs/en/plugin-marketplaces, .../plugins,
  .../plugins-reference, .../skills) manda sobre el formato de
  `plugin.json`, `marketplace.json` y `SKILL.md`. Ante duda, se relee la
  doc; no se confía en memoria previa.
- No afirmar que algo funciona sin haberlo ejecutado de verdad (instalar el
  plugin y correr el comando).
- El comando se implementa como skill con `disable-model-invocation: true`:
  así su descripción no ocupa contexto y el cuerpo solo se carga cuando el
  usuario lo invoca explícitamente. Es la restricción de diseño central del
  proyecto: no añadir consumo permanente de contexto.

## Criterio de terminado (v0.1)
En una máquina limpia: `/plugin marketplace add <repo>` +
`/plugin install ahorro-tokens@ahorro-tokens-marketplace`, y al ejecutar
`/ahorro-tokens:auditoria-tokens` sobre este mismo proyecto se obtiene un
informe útil con coste de tokens de CLAUDE.md, servidores MCP detectados y 3
acciones de ahorro concretas.

## Fuera de alcance
Interfaz gráfica, telemetría, comandos adicionales, cualquier plataforma de
pago.
