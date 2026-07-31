---
description: Audita el coste en tokens de CLAUDE.md, los servidores MCP configurados en este proyecto, y sugiere las 3 acciones que más reducirían ese consumo.
disable-model-invocation: true
allowed-tools: Bash(wc *) Bash(claude mcp list) Bash(${CLAUDE_SKILL_DIR}/scripts/find-claude-md.sh)
---

# Auditoría de tokens

Audita el proyecto actual (el directorio de trabajo donde se invoca este
comando, no `/opt/skill`) y genera un informe corto con exactamente estas
tres secciones numeradas. No añadas saludos ni preguntas de seguimiento.

## 1. Coste en tokens de CLAUDE.md

Ejecuta `${CLAUDE_SKILL_DIR}/scripts/find-claude-md.sh`. Devuelve dos listas
de rutas, cada una bajo su propia cabecera `## ancestros` y `## anidados`:

- **Ancestros**: el directorio de trabajo actual y cada directorio padre
  hasta la raíz del filesystem. Claude Code carga estos ficheros enteros en
  cada sesión, así que su coste es garantizado ("always-on").
- **Anidados**: ficheros en subcarpetas por debajo del directorio actual.
  Claude Code solo los carga si durante la sesión llega a leer un fichero de
  esa subcarpeta, así que su coste NO es garantizado — no los sumes al
  total de la sección de ancestros.

Para cada ruta listada en ambas secciones, usa `wc -lc <ruta> 2>&1` para
obtener líneas y caracteres, y estima el coste en tokens como caracteres / 4,
redondeado al entero más cercano.

- Si ninguna de las dos listas tiene rutas: informa "No se encontró ningún
  CLAUDE.md (ni de ancestros ni anidado) en este proyecto (0 tokens)."
- Si la lista de ancestros tiene una o más rutas: muéstralas una por una con
  su ruta y "~N tokens estimados (C caracteres, L líneas)", y al final la
  suma total de tokens estimados de todos los ancestros. Añade la nota:
  "Estimación aproximada (caracteres/4), no un conteo exacto de tokens."
- Si la lista de anidados tiene una o más rutas: muéstralas aparte, con la
  misma estimación por fichero, bajo un subtítulo que deje claro que su
  coste solo se paga si Claude lee algo de esa subcarpeta durante la
  sesión, no en cada turno.

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
2. Si la suma total de tokens estimados de los **ancestros** en la sección 1
   supera los 2000 tokens: sugiere recortarlo o mover contenido de
   procedimiento (listas de pasos, checklists) a skills con
   `disable-model-invocation: true`, que solo cargan al invocarlas
   explícitamente en vez de en cada turno. No cuentes los anidados para
   este umbral: su coste no es garantizado en cada sesión.
3. Si ninguna de las reglas anteriores aplica: dilo explícitamente — "Con
   las señales analizadas en v0.1 (CLAUDE.md y servidores MCP) no se
   detectan acciones de ahorro claras en este proyecto."

No rellenes con acciones genéricas si aplican menos de 3: enumera solo las
que de verdad apliquen y dilo así.
