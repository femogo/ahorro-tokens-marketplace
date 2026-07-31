# Estado

**Fase actual**: v1.0.0 publicada. Commiteado y pusheado a `origin/main`:
mejora B (CLAUDE.md anidados, `158cead`), refactor a statusLine + panel bajo
demanda + skill fina (`fbeac13`), aclaración de ventana nominal vs buffer de
autocompactación en el panel (`4e60e1c`), y versión `1.0.0` fijada en
`plugin.json` con tag `ahorro-tokens--v1.0.0` (`5d36d32`), lista para el
formulario de comunidad de Anthropic.

El usuario decidió descartar A y C para v1.0.0 (ver secciones A y C más
abajo para el porqué de cada una). Con eso, el roadmap v1.0 queda cerrado
tal cual está publicado: no hay más código pendiente de escribir para esta
versión.

**Repositorio**: https://github.com/femogo/ahorro-tokens-marketplace
(**público**), rama `main`.

**Regla de colaboración fijada por el usuario (importante para cualquier
sesión futura)**: nunca reescribir historial de git (`filter-branch`,
`rebase` sobre commits ya pusheados, `commit --amend` sobre commits
pusheados) ni hacer `push --force`/`--force-with-lease` por iniciativa
propia. Siempre proponer el comando exacto y esperar confirmación explícita
antes de ejecutarlo, aunque parezca de bajo riesgo o esté implícito en una
petición más general. (Guardado también como memoria persistente,
`git_history_confirmation.md`, porque aplica más allá de este proyecto.)

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

**Prueba anónima tras hacer el repo público** (lo más parecido a una máquina
limpia sin levantar otra VM): desinstalado plugin y marketplace, y repetido
el ciclo completo con `GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0`
para anular las credenciales de git. Resultado: Claude Code detectó "SSH not
configured" y cayó a HTTPS solo, clonó el repo público **sin credenciales**,
instaló y ejecutó bien desde `/root` (rama "no hay CLAUDE.md"). Después se
repitió con el entorno normal y el comando tal cual del README, también
correcto.

Nota sobre el error de SSH del principio: ocurrió antes de ejecutar
`gh auth setup-git` (no existía `~/.gitconfig`). Después ya no se reproduce.
No he confirmado la lógica interna exacta de esa detección, así que el README
lo describe como un fallo posible según la máquina, no como algo seguro.

---

## Roadmap v1.0

El usuario pidió llevar el plugin de v0.1 a v1.0. Se propusieron 4 mejoras
(A-D); esto documenta dónde quedó cada una tras investigar. **No se ha
escrito código de v1.0 todavía** — esta sesión fue solo de investigación y
planificación, a propósito, porque el usuario iba a hacer `/clear` después.

### A — Coste de skills/plugins autocargados de otros plugins

**Investigado, salvedad confirmada (ver más abajo), y descartado para
v1.0.0 por decisión del usuario**: se espera a que Anthropic aclare o
corrija el sobrecoste de `claude plugin details` para skills con
`disable-model-invocation: true` antes de construir nada sobre ese dato.

Existe un comando oficial documentado para esto:
`claude plugin details <plugin>@<marketplace>` — "Show a plugin's component
inventory and projected token cost" (`plugins-reference.md`, sección
"plugin details"). Muestra, por plugin: inventario de componentes (Skills,
Agents, Hooks, MCP servers, LSP servers) y dos cifras de coste:
- **Always-on**: tokens añadidos a cada sesión por el texto de listado
  (descripciones, nombres), pase lo que pase.
- **On-invoke**: coste de cada componente cuando se dispara.

El "Always-on" total se calcula con la API real `count_tokens` del modelo
activo (no la heurística caracteres/4 que usa v0.1), con fallback a
caracteres si la API no está disponible.

Probado en real sobre el propio `ahorro-tokens`:
```
claude plugin details ahorro-tokens@ahorro-tokens-marketplace
```
dio `Skills (1) auditoria-tokens`, `Always-on: ~84 tok`.

**La salvedad**: `auditoria-tokens` tiene `disable-model-invocation: true`,
y la documentación de skills afirma que con ese flag "la descripción no
entra en contexto" (tabla en `skills.md`, columna "Description not in
context, full skill loads when you invoke"). Pero `plugin details` sigue
contando ~84 tokens de "always-on" para esa misma skill, y su propia
documentación dice que ese número se cuenta "regardless of whether any
component fires". **No he podido confirmar si `plugin details` excluye
correctamente el coste real de las skills con `disable-model-invocation:
true`, o si sobreestima.** Si sobreestima, usar sus números tal cual en el
informe de auditoría induciría a error (irónicamente, sobre el propio
ahorro-tokens, que se diseñó para costar ~0 permanente).

**Salvedad confirmada** (sesión posterior a la publicación de v1.0.0):
comparación directa con un plugin de sondaje desechable (`sondaje`, creado y
borrado solo para esta prueba, con dos skills de descripción idéntica byte
a byte, una con `disable-model-invocation: true` y otra sin el campo).
`claude plugin details` reportó el **mismo** coste "always-on" (~80 tok)
para ambas. Confirma que `plugin details` **sobreestima** el coste real de
las skills con `disable-model-invocation: true`: las cuenta como si su
descripción entrara siempre en contexto, cuando la documentación de skills
dice que no debería ser así.

**Decisión del usuario**: dejar A fuera de v1.0.0 por completo (opción 3 de
las 3 que se le presentaron), en vez de usar los números de `plugin details`
con una nota de salvedad, o ajustarlos manualmente detectando
`disable-model-invocation: true` en cada `SKILL.md`. Se espera a que
Anthropic aclare o corrija el comportamiento antes de retomarlo.

**Plan de implementación, si se retoma en el futuro**: enumerar plugins con
`claude plugin list`, quedarse solo con los `enabled`, llamar `claude plugin
details <nombre>` por cada uno, sumar/listar "Always-on" por plugin
(excluyendo o no a `ahorro-tokens` mismo, a decidir). Requiere añadir
`Bash(claude plugin list)` y `Bash(claude plugin details *)` a
`allowed-tools` en `SKILL.md`.

### B — CLAUDE.md anidados (no solo el de la raíz)

**Implementado y verificado de verdad en esta sesión.**

Verificación contra `code.claude.com/docs/en/memory` (sección "How CLAUDE.md
files load"), no de memoria previa:
- Claude Code sube el árbol de directorios desde el directorio de trabajo
  hasta la raíz del filesystem, y carga **enteros, en cada sesión**, todos
  los `CLAUDE.md`/`CLAUDE.local.md` de ese camino ("ancestros"). No hay
  límite de profundidad documentado ni comando CLI para listarlos aparte de
  recorrerlos.
- Además descubre `CLAUDE.md`/`CLAUDE.local.md` en subcarpetas por debajo
  del directorio de trabajo ("anidados"), pero **no los carga al arrancar**:
  solo entran en contexto si Claude llega a leer un fichero de esa
  subcarpeta durante la sesión. Coste no garantizado, por tanto no debe
  sumarse al de los ancestros.

Implementación: script nuevo
`plugins/ahorro-tokens/skills/auditoria-tokens/scripts/find-claude-md.sh`
(bundleado con el plugin, se referencia con `${CLAUDE_SKILL_DIR}` tal como
documenta `skills.md`), que imprime dos listas separadas (`## ancestros` /
`## anidados`) siguiendo exactamente esa lógica. `SKILL.md` sección 1
reescrita para: ejecutar el script, hacer `wc -lc` de cada ruta encontrada,
sumar el total solo de ancestros para el umbral de la acción 2, y reportar
los anidados aparte con su salvedad. `allowed-tools` ampliado con
`Bash(${CLAUDE_SKILL_DIR}/scripts/find-claude-md.sh)`.

**Verificado de verdad, no solo "debería funcionar"**:
- Script probado directamente: detecta el ancestro de este repo
  (`/opt/skill/CLAUDE.md`) desde una subcarpeta, y un `CLAUDE.md` de prueba
  en subcarpeta como anidado, cada uno bajo su cabecera correcta.
- Ciclo completo con el plugin instalado de verdad (no solo el script
  suelto): añadido temporalmente un marketplace local apuntando a
  `/opt/skill` (`claude plugin marketplace add /opt/skill`, mismo nombre
  que el ya configurado, así que lo repuntó), `claude plugin update
  ahorro-tokens@ahorro-tokens-marketplace`, y ejecutado `claude -p
  "/ahorro-tokens:auditoria-tokens"` como proceso nuevo (el proceso de esta
  sesión no recoge cambios de plugin sin reiniciar, así que la única forma
  de probarlo de verdad era un `claude -p` aparte). Dos casos, ambos
  correctos:
  - Sin anidados: sección 1 solo con "Ancestros" (~395 tokens, igual que
    siempre) y "Anidados: ninguno encontrado."
  - Con un `CLAUDE.md` de prueba en `plugins/testsub/` (63 caracteres, 2
    líneas, borrado después de la prueba): apareció correctamente bajo
    "Anidados" con su propia estimación (~16 tokens) y la nota de que su
    coste no es garantizado, sin sumarse al total de ancestros ni disparar
    la acción 2 del umbral de 2000 tokens.
- Después de la prueba, repuesto el marketplace a su origen real
  (`claude plugin marketplace add https://github.com/femogo/ahorro-tokens-marketplace`)
  para no dejar la configuración del usuario alterada. **Nota para la
  próxima sesión**: el caché de plugin de esta máquina
  (`~/.claude/plugins/cache/.../76e13ae02b37/`) quedó con el contenido de
  la prueba local (incluye ya `scripts/find-claude-md.sh`) aunque ese
  commit no existe todavía en GitHub — es solo caché local de este
  contenedor, no afecta al repo público, pero si algo raro pasa con
  versiones de plugin más adelante, puede ser la causa.

**Pendiente, no de investigación sino de decisión del usuario**: los
cambios de código (`SKILL.md`, script nuevo) están hechos y verificados
mano a mano en local, pero **sin commitear ni pushear** — pendiente de que
el usuario lo pida explícitamente.

### C — Contar herramientas por servidor MCP

**Investigado: requiere invocar/conectar al servidor. No es posible leyendo
solo la configuración estática. Parado aquí, como se pidió, sin implementar
nada.**

Comprobado:
- `claude mcp list --help` y `claude mcp get --help` no tienen flag `--json`
  ni ninguna opción de salida estructurada.
- Probado en real: `claude mcp get "claude.ai Dice"` solo devuelve `Scope` y
  `Status` — ningún recuento de herramientas.
- La documentación dice explícitamente que el recuento de herramientas por
  servidor solo aparece en el panel interactivo `/mcp` ("shows the tool
  count next to each connected server"), que no es invocable desde una
  skill no interactiva (`-p`).
- El recuento no vive en la configuración estática (`.mcp.json` /
  `~/.claude.json` solo tienen `command`/`args`/`url`, no herramientas): se
  descubre dinámicamente hablando el protocolo MCP con el servidor
  (`tools/list`), lo que exige conectar de verdad.

**Decisión del usuario**: descartar C para v1.0.0. El informe se queda como
está (lista servidores MCP conectados, sin desglosar sus herramientas).

### D y lo dejado fuera

Sin cambios: de acuerdo con el usuario en mantener conteo real de tokens
para CLAUDE.md (heurística caracteres/4 vale por ahora) y en no añadir
histórico/diffing ni umbral configurable todavía.

### Siguiente acción concreta

Ninguna: las tres acciones de esta lista están cerradas.

1. ~~Decidir con el usuario si se commitea y pushea B~~ — hecho, commiteado
   y pusheado (`158cead`, y confirmado de nuevo en `origin/main` tras el
   push de v1.0.0).
2. ~~Aclarar la salvedad de A~~ — hecho, confirmada (ver sección A). El
   usuario decidió descartar A para v1.0.0.
3. ~~Hablar con el usuario sobre C~~ — hecho, descartada para v1.0.0.

El roadmap v1.0 queda cerrado con lo ya publicado (B, el refactor de
statusLine/panel, y la versión `1.0.0` fijada). A y C quedan documentados
como investigados y descartados por decisión explícita del usuario, no
como pendientes.
