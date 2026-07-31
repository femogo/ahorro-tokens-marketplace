---
description: Audita el coste en tokens de CLAUDE.md, los servidores MCP configurados en este proyecto, y sugiere las 3 acciones que más reducirían ese consumo.
disable-model-invocation: true
allowed-tools: Bash(wc *) Bash(claude mcp list) Bash(${CLAUDE_SKILL_DIR}/scripts/find-claude-md.sh)
---

# Auditoría de tokens

Audita el proyecto actual (el directorio de trabajo donde se invoca este
comando, no `/opt/skill`) y genera un informe pensado para alguien que
nunca ha oído hablar de "tokens", "contexto" ni "servidores MCP". No
inventes cifras ni texto de relleno cuando no hay datos. No añadas
saludos ni preguntas de seguimiento del tipo "¿quieres que te ayude
con...?": el informe debe bastarse solo.

## Formato general del informe

Antes de las tres secciones, escribe una única frase en lenguaje llano
que explique qué va a hacer el análisis y por qué importa. Ejemplo de
tono (no copiar literalmente, adaptar al resultado real): "Este análisis
revisa cuánto 'peso' añade tu configuración a cada conversación con
Claude, y si hay algo fácil de aligerar."

Estructura el resto en exactamente tres secciones numeradas, cada una con
un título corto en lenguaje llano, separadas entre sí por una línea de
guiones (por ejemplo `---`) para que se lea bien en una terminal y no
como un bloque de texto continuo.

La primera vez que uses un término técnico (CLAUDE.md, servidor MCP,
contexto, tokens...) añade una aclaración de una frase, entre paréntesis
o en línea aparte. No la repitas en menciones posteriores del mismo
término.

No uses emoji decorativo. Los símbolos de estado que ya vienen
literalmente de la salida de `claude mcp list` (✔, ✘, !, ⏸, etc.) se
mantienen tal cual — no añadas otros.

Cierra el informe, fuera de las tres secciones numeradas, con una única
frase de resumen: si hay algo que conviene hacer hoy, o si todo está bien
tal como está.

## 1. Cuánto pesa tu CLAUDE.md

Ejecuta `${CLAUDE_SKILL_DIR}/scripts/find-claude-md.sh`. Devuelve dos
listas de rutas, cada una bajo su propia cabecera `## ancestros` y
`## anidados`:

- **Ancestros**: el directorio de trabajo actual y cada directorio padre
  hasta la raíz del filesystem. La primera vez que lo menciones en el
  informe, explica en una frase que un archivo CLAUDE.md contiene
  instrucciones de proyecto que Claude Code lee automáticamente, y que
  los de esta lista se cargan enteros en cada conversación sin que nadie
  los pida — por eso su coste es seguro, no ocasional.
- **Anidados**: ficheros en subcarpetas por debajo del directorio actual.
  Explica que estos solo se cargan si durante la conversación Claude
  llega a abrir un archivo de esa subcarpeta — su coste es ocasional, no
  seguro, así que no deben sumarse al total de ancestros.

Para cada ruta listada en ambas secciones, usa `wc -lc <ruta> 2>&1` para
obtener líneas y caracteres, y estima el coste en "tokens" (la unidad en
la que Claude mide el texto que procesa; aclara esto la primera vez que
lo menciones) como caracteres / 4, redondeado al entero más cercano.

- Si ninguna de las dos listas tiene rutas: informa, en lenguaje llano,
  que no se encontró ningún archivo de instrucciones de proyecto
  (0 tokens), y que por tanto esta parte no añade ningún peso a las
  conversaciones.
- Si la lista de ancestros tiene una o más rutas: muéstralas una por una
  con su ruta y "~N tokens estimados (C caracteres, L líneas)". Al final,
  suma el total de tokens estimados de todos los ancestros y da un marco
  de referencia simple:
  - Si el total es igual o inferior a 2000 tokens: indica que es un peso
    bajo, que no se nota de forma perceptible en el coste ni en la
    velocidad de respuesta por turno.
  - Si el total supera los 2000 tokens: indica que es un peso
    considerable que se paga en cada turno de cada conversación en este
    proyecto, y que empieza a ser razonable revisarlo (sin dar cifras de
    precio que no tengas).
  Añade la nota: "Estimación aproximada (caracteres/4), no un conteo
  exacto de tokens."
- Si la lista de anidados tiene una o más rutas: muéstralas aparte, con
  la misma estimación por fichero, bajo un subtítulo que deje claro, en
  lenguaje llano, que ese coste solo se paga si Claude abre algo de esa
  subcarpeta durante la conversación, no en cada turno — así que no
  necesitan la misma atención que los ancestros.

## 2. Qué herramientas externas están conectadas

Ejecuta `claude mcp list` y usa su salida tal cual, sin reinterpretarla
ni completarla con servidores que no aparezcan en ella. La primera vez
que menciones "servidor MCP", aclara en una frase que es una integración
externa (por ejemplo, con Gmail, GitHub, Slack...) que Claude Code puede
usar, y que aunque no se use en la conversación, sigue ahí ocupando
espacio.

- Si la salida lista uno o más servidores: muéstralos con su nombre y su
  estado de salud exactamente como aparecen (por ejemplo "✔ Connected",
  "! Needs authentication", "✘ Failed to connect", "⏸ Pending
  approval"). Añade el marco de referencia: cada servidor conectado
  añade sus herramientas al peso base de cada turno, se use o no en esa
  conversación concreta — así que N servidores conectados son N fuentes
  de peso fijo, independientemente de la actividad de esa conversación.
- Si la salida indica que no hay servidores configurados, o la lista
  está vacía: informa, en lenguaje llano, que no hay integraciones
  externas conectadas a este proyecto, y que por tanto esta parte no
  añade ningún peso.
- No inventes servidores, estados ni recuentos que no estén literalmente
  en la salida del comando.

## 3. Qué merece la pena hacer

Basa las acciones únicamente en los datos que ya has obtenido en las
secciones 1 y 2 (no inventes otras señales ni analices nada más). Evalúa
estas reglas en este orden y muestra como máximo 3, solo las que
apliquen. Para cada acción que apliques, estructura la explicación en
estas tres partes, en este orden:

1. **Si no haces nada**: qué coste real sigue pagándose turno a turno
   (sin alarmismo, solo el hecho).
2. **Qué hacer**: pasos concretos y ejecutables por alguien sin
   experiencia técnica — di literalmente qué comando escribir o qué
   archivo abrir, no "revisa si es necesario".
3. **Cuánto ayudaría**: una estimación cualitativa (alto / medio / bajo),
   sin inventar una cifra exacta de ahorro que no puedas calcular con los
   datos disponibles.

Reglas, en este orden:

1. Si en la sección 2 hay 1 o más servidores MCP conectados: sugiere
   revisar si todos son necesarios, indicando el número exacto
   detectado.
   - Si no haces nada: cada uno de esos servidores sigue añadiendo sus
     herramientas al peso base de cada turno, se use o no.
   - Qué hacer: abre una terminal y ejecuta `claude mcp list` para ver el
     nombre exacto de cada servidor; el que no reconozcas o no uses,
     desconéctalo con `claude mcp remove <nombre-del-servidor>`.
   - Cuánto ayudaría: alto si hay varios servidores sin usar; bajo si ya
     solo tienes los imprescindibles.
2. Si la suma total de tokens estimados de los **ancestros** en la
   sección 1 supera los 2000 tokens: sugiere recortar el CLAUDE.md o
   mover contenido de procedimiento (listas de pasos, checklists) a
   skills con `disable-model-invocation: true`, que solo cargan al
   invocarlas explícitamente en vez de en cada turno. No cuentes los
   anidados para este umbral: su coste no es garantizado en cada sesión.
   - Si no haces nada: ese peso se recarga entero en cada conversación
     nueva de este proyecto, se use o no para lo que trata ese contenido
     concreto.
   - Qué hacer: abre el archivo CLAUDE.md más pesado señalado en la
     sección 1 y busca bloques que sean listas de pasos o checklists de
     procedimiento; muévelos a un archivo nuevo
     `skills/<nombre>/SKILL.md` con `disable-model-invocation: true` en
     su cabecera, para que solo se cargue cuando alguien lo invoque
     explícitamente, no en cada turno.
   - Cuánto ayudaría: medio o alto según cuánto del contenido sea
     procedimental y no imprescindible en cada turno.
3. Si ninguna de las reglas anteriores aplica: dilo explícitamente, en
   lenguaje llano — que con las señales analizadas en esta versión
   (CLAUDE.md y servidores MCP) no se detecta nada claro que merezca la
   pena cambiar ahora mismo.

No rellenes con acciones genéricas si aplican menos de 3: enumera solo
las que de verdad apliquen y dilo así, en lenguaje llano.
