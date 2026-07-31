# ahorro-tokens

Plugin de [Claude Code](https://code.claude.com) que audita cuánto contexto
consume un proyecto y te dice qué recortar.

Expone un único comando, `/auditoria-tokens`, que analiza el proyecto desde
el que lo invocas y devuelve un informe corto con:

1. El coste estimado en tokens de su `CLAUDE.md`.
2. Los servidores MCP configurados.
3. Hasta tres acciones concretas para reducir ese consumo.

El plugin **no añade consumo permanente de contexto**: es un comando que
invocas explícitamente, no una skill autocargada. Su contenido solo entra en
el contexto cuando lo llamas.

## Instalación

```
claude plugin marketplace add femogo/ahorro-tokens-marketplace
claude plugin install ahorro-tokens@ahorro-tokens-marketplace
```

Y desde cualquier proyecto:

```
/ahorro-tokens:auditoria-tokens
```

### Si el `add` falla con un error de SSH

En algunas máquinas el atajo `owner/repo` intenta clonar por SSH, y falla con
`Host key verification failed` si GitHub no está en tu `known_hosts`. Si te
pasa, fuerza HTTPS:

```
CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1 claude plugin marketplace add femogo/ahorro-tokens-marketplace
```

## Ejemplo de salida

```
## 1. Coste en tokens de CLAUDE.md

~395 tokens estimados (1581 caracteres, 35 líneas). Estimación aproximada
(caracteres/4), no un conteo exacto de tokens.

## 2. Servidores MCP configurados

- ejemplo-servidor (https://ejemplo.com/mcp) — ✔ Connected

## 3. Las 3 acciones que más ahorrarían tokens

1. Hay 1 servidor MCP configurado. Revisa si es necesario: cada servidor MCP
   conectado añade el esquema de sus herramientas al contexto base de cada
   turno, se use o no ese turno.

No se detectan más acciones aplicables: el coste de CLAUDE.md (~395 tokens)
no supera el umbral de 2000 tokens.
```

## Alcance

Versión 0.1: solo `/auditoria-tokens`. Sin hooks, sin servidores MCP, sin
skills autocargadas.

La estimación de tokens es aproximada (caracteres ÷ 4), no un conteo real
con el tokenizador. Sirve para decidir si un `CLAUDE.md` se ha ido de las
manos, no para facturar.

El plugin no fija `version` en su manifiesto a propósito: cada commit cuenta
como una versión nueva, así que `claude plugin update` recoge los cambios
sin tener que acordarse de subir un número a mano.

## Licencia

MIT
