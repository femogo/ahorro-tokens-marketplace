---
description: Audita el coste en tokens de CLAUDE.md, los servidores MCP configurados en este proyecto, y sugiere las 3 acciones que más reducirían ese consumo.
disable-model-invocation: true
allowed-tools: Bash(wc *) Bash(claude mcp list)
---

# Auditoría de tokens

Audita el proyecto actual (el directorio de trabajo donde se invoca este
comando, no `/opt/skill`) y genera un informe corto con exactamente estas
tres secciones numeradas. No añadas saludos ni preguntas de seguimiento.

## 1. Coste en tokens de CLAUDE.md

Comprueba si existe un fichero `CLAUDE.md` en la raíz del proyecto actual
(el directorio de trabajo, no subcarpetas). Usa `wc -lc CLAUDE.md 2>&1` para
obtener líneas y caracteres en un solo comando.

- Si el fichero no existe (el comando falla con "No such file or
  directory"): informa "No se encontró CLAUDE.md en este proyecto (0
  tokens)."
- Si existe: estima el coste en tokens como caracteres / 4, redondeado al
  entero más cercano. Muestra: "~N tokens estimados (C caracteres, L
  líneas). Estimación aproximada (caracteres/4), no un conteo exacto de
  tokens."

## 2. Servidores MCP configurados

Ejecuta `claude mcp list` y usa su salida tal cual, sin reinterpretarla ni
completarla con servidores que no aparezcan en ella:

- Si la salida lista uno o más servidores: muéstralos con su nombre y su
  estado de salud exactamente como aparecen (por ejemplo "✔ Connected",
  "! Needs authentication", "✘ Failed to connect", "⏸ Pending approval").
- Si la salida indica que no hay servidores configurados, o la lista está
  vacía: informa "No hay servidores MCP configurados en este proyecto."
- No inventes servidores, estados ni recuentos que no estén literalmente en
  la salida del comando.

## 3. Las 3 acciones que más ahorrarían tokens

Basa las acciones únicamente en los datos que ya has obtenido en las
secciones 1 y 2 (no inventes otras señales ni analices nada más). Evalúa
estas reglas en este orden y muestra como máximo 3, solo las que apliquen:

1. Si en la sección 2 hay 1 o más servidores MCP: sugiere revisar si todos
   son necesarios, indicando el número exacto detectado. Motivo: cada
   servidor MCP conectado añade el esquema de sus herramientas al contexto
   base de cada turno, se use o no ese turno.
2. Si el coste estimado de CLAUDE.md en la sección 1 supera los 2000 tokens:
   sugiere recortarlo o mover contenido de procedimiento (listas de pasos,
   checklists) a skills con `disable-model-invocation: true`, que solo
   cargan al invocarlas explícitamente en vez de en cada turno.
3. Si ninguna de las reglas anteriores aplica: dilo explícitamente — "Con
   las señales analizadas en v0.1 (CLAUDE.md y servidores MCP) no se
   detectan acciones de ahorro claras en este proyecto."

No rellenes con acciones genéricas si aplican menos de 3: enumera solo las
que de verdad apliquen y dilo así.
