---
description: Audita el coste en tokens de este proyecto (CLAUDE.md, plugins, servidores MCP) y explica en lenguaje llano las acciones que más contexto ahorrarían.
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/panel.sh) Bash(${CLAUDE_SKILL_DIR}/scripts/panel.sh *)
---

# Auditoría de tokens

Ejecuta `${CLAUDE_SKILL_DIR}/scripts/panel.sh`, sin argumentos, desde el
directorio de trabajo actual (el proyecto del usuario, no el del plugin).

Toda la medición vive en ese script. Tu trabajo aquí es solo traducir su
salida para alguien que nunca ha oído hablar de "tokens", "contexto" ni
"servidores MCP".

## Reglas que no se saltan

- **No recalcules nada.** Todas las cifras del informe salen tal cual del
  panel. No estimes, no redondees a tu manera, no rellenes huecos. Si el
  panel dice que un dato no está disponible, el informe dice lo mismo.
- **Respeta las tres marcas.** `[MEDIDO]` (real, de la sesión),
  `[PROYECTADO]` (lo calcula Claude Code) y `[ESTIMADO]` (caracteres/4).
  Explícalas una vez en llano y no mezcles cifras de marcas distintas en
  una misma suma ni en una misma comparación.
- **Los comandos se copian literalmente** del panel, con sus comillas
  dobles. No los reescribas ni los "mejores": el usuario objetivo no sabrá
  arreglarlos si fallan.
- Si el script falla, no existe o no devuelve nada: dilo claramente y
  termina ahí. No improvises una auditoría a mano.
- Sin emoji. Los símbolos que ya vengan de la salida de `claude mcp list`
  (✔, ✘, !, ⏸) se mantienen tal cual.
- Sin saludos y sin preguntas de seguimiento del tipo "¿quieres que…?".
  El informe se basta solo.

## Estructura del informe

**Primero**, una frase en lenguaje llano que diga qué se ha mirado y por
qué importa.

**Después**, la salida del panel tal cual, dentro de un bloque de código.
No la resumas ni la recortes: es la parte medida y el usuario tiene que
poder verla entera.

**Después**, tu lectura, en tres secciones cortas separadas por `---`:

1. **Cómo está tu sesión ahora.** A partir de la sección 1 del panel. Si
   no hay datos de sesión, explica que hace falta activar la statusLine y
   reproduce el bloque de configuración que imprime el propio panel.
2. **De dónde viene el peso.** A partir de las secciones 2, 3 y 4:
   archivos de instrucciones, plugins y servidores MCP. Ordena lo que
   pese más primero, y di siempre con qué marca está medido.
3. **Qué merece la pena hacer.** Máximo tres acciones, priorizadas según
   las reglas de abajo.

La primera vez que aparezca un término técnico, acláralo en una frase y
no lo repitas después: token (la unidad en que Claude mide el texto,
aproximadamente cuatro caracteres), ventana de contexto (todo lo que
Claude puede tener presente a la vez en una conversación), CLAUDE.md
(archivo de instrucciones que se carga solo por estar donde está),
servidor MCP (integración externa —Gmail, GitHub, Slack…— que añade sus
herramientas a cada conversación aunque no se usen), coste fijo
(lo que se paga en cada turno, se use o no).

## Cómo priorizar las acciones

Aplica estas reglas en este orden y quédate con las tres primeras que
apliquen de verdad. Para cada una, escribe tres cosas: **si no haces
nada** (qué se sigue pagando), **qué hacer** (el comando literal del
panel, o qué archivo abrir) y **cuánto ayudaría** (alto / medio / bajo,
sin inventar una cifra de ahorro que no esté en el panel).

1. Si la sesión medida va por encima del 70% de la ventana: lo urgente es
   eso, no la configuración. Sugiere `/compact`, o abrir una sesión nueva
   para la siguiente tarea.
2. Si hay servidores MCP conectados: es el coste fijo más habitual y el
   panel no puede ponerle cifra, así que preséntalo por número de
   servidores, no por tokens. Comando de retirada, el del panel.
3. Si en "se cargan siempre" aparece algún CLAUDE.md fuera del proyecto
   actual (por ejemplo en el directorio personal o en una carpeta
   superior): señálalo como peso que probablemente el usuario no recuerda
   haber puesto ahí, porque se carga en todos los proyectos que cuelgan
   de esa carpeta.
4. Si el total estimado de "se cargan siempre" pasa de 2.000 tokens:
   sugiere mover los bloques de procedimiento (listas de pasos,
   checklists) a una skill con `disable-model-invocation: true`, que solo
   se carga al invocarla.
5. Si algún plugin tiene un coste fijo proyectado alto y el usuario no lo
   usa: `claude plugin disable "<nombre>"`, que es reversible. Menciona
   `uninstall` solo como segunda opción.

Si no aplica ninguna, dilo en llano: con lo que se ve hoy no hay nada que
merezca la pena tocar. No rellenes hasta tres.

**Cierra** con una sola frase: si hay algo que conviene hacer hoy, o si
todo está razonable como está.
