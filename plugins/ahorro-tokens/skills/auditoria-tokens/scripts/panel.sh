#!/usr/bin/env bash
# panel.sh — panel de contexto bajo demanda.
#
# Reúne en una sola pantalla de dónde sale el contexto que consume una sesión
# de Claude Code, distinguiendo SIEMPRE tres tipos de cifra que no son
# comparables entre sí y que por tanto nunca se suman juntas:
#
#   [MEDIDO]      Dato real de la sesión, capturado por statusline.sh (fase 1)
#                 desde el payload que entrega Claude Code.
#   [PROYECTADO]  Lo calcula Claude Code en `claude plugin details`. Ojo: su
#                 propia salida termina diciendo "Token counts are estimates
#                 and may differ from actual usage", así que es un cálculo
#                 suyo, más fiable que el nuestro pero no una medición.
#   [ESTIMADO]    Lo calculamos aquí: caracteres/4. Solo orientativo.
#
# Reglas de presentación (ver también la fase 3, que solo envuelve esto):
#   - Si un dato no se puede obtener, se dice. No se rellena ni se inventa.
#   - Los porcentajes van con un decimal y SIEMPRE sobre el context_window_size
#     real. Sin ese dato no se da porcentaje.
#   - Los comandos sugeridos se pueden copiar y pegar tal cual: los nombres con
#     espacios van entre comillas dobles.
#   - Sin emoji. Barras ASCII.
#
# Uso: panel.sh [directorio]   (por defecto, el directorio actual)

export LC_ALL=C

# Directorio del propio script. panel.sh vive dentro de la skill (y no en
# plugins/ahorro-tokens/scripts/) porque la única variable que Claude Code
# sustituye dentro de una skill es ${CLAUDE_SKILL_DIR}, que apunta a la
# subcarpeta de la skill, no a la raíz del plugin: desde SKILL.md no hay forma
# de nombrar un script que esté fuera de aquí.
aqui="$(cd "$(dirname "$0")" && pwd)"
buscador="$aqui/find-claude-md.sh"

# statusline.sh sí se queda en la raíz del plugin, porque a ese lo invoca
# Claude Code por ruta absoluta desde settings.json, no la skill. Se busca en
# los dos sitios para poder sugerir su ruta real.
ruta_statusline=""
for c in "$aqui/statusline.sh" "$aqui/../../../scripts/statusline.sh"; do
  if [ -f "$c" ]; then ruta_statusline="$(cd "$(dirname "$c")" && pwd)/statusline.sh"; break; fi
done

proyecto="${1:-$PWD}"
cd "$proyecto" 2>/dev/null || { echo "No existe el directorio: $proyecto"; exit 1; }
proyecto="$PWD"

cache_dir="${AHORRO_TOKENS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/ahorro-tokens}"

# Un volcado más antiguo que esto se considera de otra sesión o caducado.
umbral_obsoleto=900   # 15 minutos

# Tiempo máximo que se espera a cada subcomando `claude` (mcp list hace
# comprobaciones de salud por red y puede tardar).
espera=45

# --- utilidades --------------------------------------------------------------

hay() { command -v "$1" >/dev/null 2>&1; }

# Ejecuta un comando con límite de tiempo si el sistema tiene `timeout`.
con_espera() {
  if hay timeout; then timeout "$espera" "$@"; else "$@"; fi
}

es_entero() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

# 200000 -> 200k ; 45231 -> 45.2k ; 812 -> 812
formatea() {
  n="$1"
  es_entero "$n" || { printf '%s' "$n"; return; }
  if [ "$n" -lt 1000 ]; then printf '%s' "$n"
  elif [ $(( n % 1000 )) -eq 0 ]; then printf '%sk' $(( n / 1000 ))
  else d=$(( n / 100 )); printf '%s.%sk' $(( d / 10 )) $(( d % 10 ))
  fi
}

# Porcentaje con un decimal, aritmética entera y redondeo al más cercano
# (truncar hacía que "ocupado 22.6% + libre 77.3%" sumara 99.9%).
pct() {
  es_entero "$1" && es_entero "$2" && [ "$2" -gt 0 ] || { printf '?'; return; }
  p=$(( ( $1 * 1000 + $2 / 2 ) / $2 ))
  # Algo que existe pero no llega al 0.05% se enseña como "<0.1", no como
  # "0.0": un 0.0 se lee como "esto no ocupa nada".
  if [ "$p" -eq 0 ] && [ "$1" -gt 0 ]; then printf '<0.1'; return; fi
  printf '%s.%s' $(( p / 10 )) $(( p % 10 ))
}

# Barra ASCII de 40 casillas.
barra() {
  es_entero "$1" && es_entero "$2" && [ "$2" -gt 0 ] || return
  llenas=$(( $1 * 40 / $2 ))
  [ "$llenas" -gt 40 ] && llenas=40
  [ "$llenas" -lt 0 ] && llenas=0
  printf '   ['
  i=0; while [ $i -lt 40 ]; do
    [ $i -lt "$llenas" ] && printf '#' || printf '.'
    i=$(( i + 1 ))
  done
  printf ']\n'
}

# Convierte "~3.4k" / "~84" / "1.2M" a un entero de tokens.
a_tokens() {
  v="$(printf '%s' "$1" | tr -d '~ ')"
  case "$v" in
    *k|*K) n="${v%[kK]}"; escala=1000 ;;
    *M|*m) n="${v%[Mm]}"; escala=1000000 ;;
    *)     n="$v";        escala=1 ;;
  esac
  case "$n" in
    *.*) ent="${n%%.*}"; dec="${n#*.}"; dec="${dec}0"; dec="$(printf '%s' "$dec" | cut -c1)"
         es_entero "$ent" && es_entero "$dec" || { printf '0'; return; }
         printf '%s' $(( ent * escala + dec * escala / 10 )) ;;
    *)   es_entero "$n" || { printf '0'; return; }
         printf '%s' $(( n * escala )) ;;
  esac
}

# Caracteres de un fichero. Con locale UTF-8 si existe (si no, wc -c cuenta
# bytes y las tildes inflan un poco la cifra: es una estimación, se avisa).
caracteres() {
  c="$(LC_ALL=C.UTF-8 wc -m < "$1" 2>/dev/null)" || c=""
  [ -n "$c" ] || c="$(wc -c < "$1" 2>/dev/null)"
  printf '%s' "${c:-0}" | tr -d ' '
}

# La estimación del proyecto: 1 token ~ 4 caracteres.
tokens_estimados() { c="$(caracteres "$1")"; es_entero "$c" && printf '%s' $(( c / 4 )) || printf '0'; }

separador() { printf -- '----------------------------------------------------------------------\n'; }

titulo() { printf '\n'; separador; printf ' %s\n' "$1"; separador; }

# --- 1. Sesión: lo único MEDIDO ---------------------------------------------
#
# Se lee el volcado más reciente que dejó la statusLine. No hay forma de saber
# desde un script cuál es el session_id de la sesión que lo está ejecutando,
# así que se usa el más reciente y se dice de cuál se trata y qué antigüedad
# tiene, para que el usuario pueda descartarlo si no le cuadra.

ventana=""        # context_window_size real
usados=""         # tokens de entrada actuales
cache_usada=""
cache_edad=""
cache_sesion=""
cache_estado=""   # ok | sin-cache | sin-medir | ilegible

leer_sesion() {
  [ -d "$cache_dir" ] || { cache_estado="sin-cache"; return; }

  # El más reciente por fecha de modificación, excluyendo ultima.json (que es
  # un enlace a uno de ellos y duplicaría la entrada).
  reciente=""
  for f in "$cache_dir"/*.json; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in ultima.json) continue ;; esac
    if [ -z "$reciente" ] || [ "$f" -nt "$reciente" ]; then reciente="$f"; fi
  done
  [ -n "$reciente" ] || { cache_estado="sin-cache"; return; }

  cache_usada="$reciente"
  mtime="$(stat -c %Y "$reciente" 2>/dev/null || date -r "$reciente" +%s 2>/dev/null)"
  ahora="$(date +%s)"
  es_entero "$mtime" && cache_edad=$(( ahora - mtime )) || cache_edad=""

  payload="$(cat "$reciente" 2>/dev/null)"
  [ -n "$payload" ] || { cache_estado="ilegible"; return; }

  if hay jq; then
    ventana="$(printf '%s' "$payload" | jq -r '.context_window.context_window_size // ""' 2>/dev/null)"
    cache_sesion="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)"
    usados="$(printf '%s' "$payload" | jq -r '
      def n(x): if (x|type)=="number" then x else 0 end;
      if .context_window.current_usage == null then ""
      else ( n(.context_window.current_usage.input_tokens)
           + n(.context_window.current_usage.cache_creation_input_tokens)
           + n(.context_window.current_usage.cache_read_input_tokens) ) | tostring
      end' 2>/dev/null)"
  else
    # Mismo parseo POSIX que statusline.sh: se trocea por comas y llaves para
    # que "input_tokens" no capture "cache_read_input_tokens".
    num_de() {
      printf '%s' "$payload" | tr ',{}' '\n\n\n' |
        sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9.]*\).*/\1/p" | head -n1
    }
    ventana="$(num_de context_window_size)"
    cache_sesion="$(printf '%s' "$payload" | tr ',{}' '\n\n\n' |
      sed -n 's/^[[:space:]]*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    e="$(num_de input_tokens)"; c="$(num_de cache_creation_input_tokens)"; l="$(num_de cache_read_input_tokens)"
    if [ -n "$e$c$l" ]; then usados=$(( ${e:-0} + ${c:-0} + ${l:-0} )); fi
  fi

  # Igual que en la statusLine: sin tokens medidos no hay porcentaje. Un
  # current_usage null significa "aún no medido", no "ventana vacía".
  if es_entero "$usados"; then cache_estado="ok"; else cache_estado="sin-medir"; fi
}

seccion_sesion() {
  titulo "1. TU SESIÓN AHORA MISMO                              [MEDIDO]"
  case "$cache_estado" in
    ok)
      printf '   Ventana total:  %s tokens\n' "$(formatea "$ventana")"
      if es_entero "$ventana" && [ "$ventana" -gt 0 ]; then
        libre=$(( ventana - usados )); [ "$libre" -lt 0 ] && libre=0
        printf '   Ocupado:        %s tokens  (%s%%)\n' "$(formatea "$usados")" "$(pct "$usados" "$ventana")"
        printf '   Libre:          %s tokens  (%s%%)\n' "$(formatea "$libre")" "$(pct "$libre" "$ventana")"
        barra "$usados" "$ventana"
      else
        printf '   Ocupado:        %s tokens\n' "$(formatea "$usados")"
        printf '   Sin context_window_size en el volcado: no se da porcentaje.\n'
      fi
      printf '\n   Origen: %s\n' "$cache_usada"
      [ -n "$cache_sesion" ] && printf '   Sesión: %s\n' "$cache_sesion"
      if es_entero "$cache_edad"; then
        if [ "$cache_edad" -gt "$umbral_obsoleto" ]; then
          printf '   AVISO: el dato tiene %s minutos. Puede ser de otra sesión ya\n' $(( cache_edad / 60 ))
          printf '          cerrada. Si no te cuadra, no lo uses.\n'
        else
          printf '   Antigüedad: %s segundos.\n' "$cache_edad"
        fi
      fi
      ;;
    sin-medir)
      printf '   Hay volcado, pero current_usage viene a null: la sesión todavía\n'
      printf '   no ha hecho ninguna llamada a la API, o acabas de compactar.\n'
      printf '   No se estima nada: vuelve a lanzar el panel tras un par de turnos.\n'
      [ -n "$cache_usada" ] && printf '\n   Origen: %s\n' "$cache_usada"
      ;;
    ilegible)
      printf '   El volcado existe pero no se puede leer: %s\n' "$cache_usada"
      ;;
    *)
      printf '   Sin datos de sesión: activa la statusLine para verlos.\n\n'
      printf '   Añade esto a ~/.claude/settings.json y reinicia Claude Code:\n\n'
      printf '     "statusLine": {\n'
      printf '       "type": "command",\n'
      if [ -n "$ruta_statusline" ]; then
        printf '       "command": "%s",\n' "$ruta_statusline"
      else
        # No se encontró el script: mejor decirlo que dar una ruta inventada.
        printf '       "command": "<ruta a statusline.sh, no localizado>",\n'
      fi
      printf '       "padding": 0\n'
      printf '     }\n\n'
      printf '   Sin eso, el tamaño real de tu ventana y los tokens que llevas\n'
      printf '   gastados no son accesibles desde un script, y aquí no se inventan.\n'
      ;;
  esac
}

# --- 2. Ficheros en disco: ESTIMADO -----------------------------------------

total_ancestros=0
total_anidados=0

listar_claude_md() {
  if [ ! -f "$buscador" ]; then
    printf '   No se encuentra find-claude-md.sh (esperado en %s).\n' "$buscador"
    printf '   No se listan los CLAUDE.md: sin ese script no se puede saber\n'
    printf '   cuáles carga Claude Code.\n'
    return
  fi

  salida="$(bash "$buscador" 2>/dev/null)"
  seccion=""
  hubo_ancestros=0
  hubo_anidados=0

  printf '   CLAUDE.md de ancestros (se cargan SIEMPRE, en cada sesión)\n'

  # Primera pasada: ancestros. Se usa heredoc y no tubería, para que las
  # sumas se queden en este shell y no en un subshell.
  seccion=""
  while IFS= read -r linea; do
    case "$linea" in
      '## ancestros') seccion=a; continue ;;
      '## anidados')  seccion=n; continue ;;
      '') continue ;;
    esac
    if [ "$seccion" = a ] && [ -f "$linea" ]; then
      t="$(tokens_estimados "$linea")"
      total_ancestros=$(( total_ancestros + t ))
      hubo_ancestros=1
      printf '     ~%-8s %s\n' "$(formatea "$t") tok" "$linea"
    fi
  done <<EOF
$salida
EOF
  [ "$total_ancestros" -eq 0 ] && printf '     (ninguno)\n'
  if [ "$total_ancestros" -gt 0 ]; then
    printf '     %-9s TOTAL siempre cargado  [ESTIMADO]\n' "~$(formatea "$total_ancestros") tok"
    if es_entero "$ventana" && [ "$ventana" -gt 0 ]; then
      printf '                que es un %s%% de tu ventana de %s\n' \
        "$(pct "$total_ancestros" "$ventana")" "$(formatea "$ventana")"
    fi
  fi

  # Segunda pasada: anidados.
  printf '\n   CLAUDE.md anidados (solo cuentan si Claude lee esa subcarpeta)\n'
  seccion=""
  while IFS= read -r linea; do
    case "$linea" in
      '## ancestros') seccion=a; continue ;;
      '## anidados')  seccion=n; continue ;;
      '') continue ;;
    esac
    if [ "$seccion" = n ] && [ -f "$linea" ]; then
      t="$(tokens_estimados "$linea")"
      total_anidados=$(( total_anidados + t ))
      printf '     ~%-8s %s\n' "$(formatea "$t") tok" "$linea"
    fi
  done <<EOF
$salida
EOF
  if [ "$total_anidados" -gt 0 ]; then
    printf '     %-9s TOTAL potencial, NO sumado al de arriba\n' "~$(formatea "$total_anidados") tok"
  else
    printf '     (ninguno)\n'
  fi
}

# Recuento de un directorio de ~/.claude (skills, agents, commands).
listar_dir_usuario() {
  etiqueta="$1"; dir="$2"; patron="$3"; nota="$4"

  printf '\n   %s\n' "$etiqueta"
  if [ ! -d "$dir" ]; then
    printf '     (no existe %s)\n' "$dir"
    return
  fi

  ficheros="$(find "$dir" -maxdepth 2 -name "$patron" -type f 2>/dev/null | sort)"
  [ -n "$ficheros" ] || { printf '     (vacío)\n'; return; }

  # Heredoc en vez de tubería: así el contador y la suma sobreviven al bucle.
  n=0; suma=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    t="$(tokens_estimados "$f")"
    n=$(( n + 1 )); suma=$(( suma + t ))
    printf '     ~%-8s %s\n' "$(formatea "$t") tok" "${f#$HOME/}"
  done <<EOF
$ficheros
EOF
  printf '     %s fichero(s), ~%s tok en total  [ESTIMADO]\n' "$n" "$(formatea "$suma")"
  [ -n "$nota" ] && printf '     %s\n' "$nota"
}

seccion_disco() {
  titulo "2. FICHEROS EN DISCO                                [ESTIMADO]"
  printf '   Cifras calculadas como caracteres/4. Son orientativas: el\n'
  printf '   tokenizador real no parte exactamente así.\n\n'
  listar_claude_md
  listar_dir_usuario "Skills de usuario (~/.claude/skills)" "$HOME/.claude/skills" "SKILL.md" \
    "De cada skill, en cada sesión solo pesa su descripción; el cuerpo se carga al invocarla."
  listar_dir_usuario "Agentes de usuario (~/.claude/agents)" "$HOME/.claude/agents" "*.md" \
    "Su descripción se carga siempre; el cuerpo, al lanzar el agente."
  listar_dir_usuario "Comandos de usuario (~/.claude/commands)" "$HOME/.claude/commands" "*.md" \
    "El cuerpo se carga al ejecutar el comando."
}

# --- 3. Plugins: PROYECTADO por Claude Code ---------------------------------

seccion_plugins() {
  titulo "3. PLUGINS INSTALADOS                             [PROYECTADO]"
  if ! hay claude; then
    printf '   No se encuentra el ejecutable `claude`: no se puede consultar.\n'
    return
  fi

  lista="$(con_espera claude plugin list 2>/dev/null)"
  if [ -z "$lista" ]; then
    printf '   `claude plugin list` no devolvió nada (o tardó más de %ss).\n' "$espera"
    return
  fi

  # Las líneas de plugin son las que llevan "nombre@marketplace"; las de
  # detalle (Version:, Scope:, Status:) llevan dos puntos. Se quita el marcador
  # de selección que antepone la CLI.
  nombres="$(printf '%s\n' "$lista" | sed 's/^[[:space:]]*//; s/^[^A-Za-z0-9_.-]*[[:space:]]*//' |
    grep '@' | grep -v ':' | sed 's/[[:space:]]*$//')"

  if [ -z "$nombres" ]; then
    printf '   No hay plugins instalados.\n'
    return
  fi

  printf '   Cifras de `claude plugin details`. Las calcula Claude Code, no\n'
  printf '   nosotros. Su propia salida avisa de que son estimaciones suyas,\n'
  printf '   así que NO se mezclan con lo medido ni con nuestro caracteres/4.\n'
  total_siempre=0

  while IFS= read -r nombre; do
    [ -n "$nombre" ] || continue
    det="$(con_espera claude plugin details "$nombre" 2>/dev/null)"
    if [ -z "$det" ]; then
      printf '\n   %s\n     (no se pudieron obtener los detalles)\n' "$nombre"
      continue
    fi
    siempre="$(printf '%s\n' "$det" | sed -n 's/.*Always-on:[[:space:]]*\([^ ]*\)[[:space:]]*tok.*/\1/p' | head -n1)"
    printf '\n   %s\n' "$nombre"
    if [ -n "$siempre" ]; then
      st="$(a_tokens "$siempre")"
      total_siempre=$(( total_siempre + st ))
      printf '     Siempre en contexto: ~%s tok\n' "$(formatea "$st")"
    else
      printf '     Siempre en contexto: no informado por `claude plugin details`\n'
    fi
    # Componentes y su coste, tal cual los lista Claude Code. Se le pone
    # cabecera propia porque la suya ("component always-on on-invoke") no
    # dice nada a quien no conoce la jerga.
    componentes="$(printf '%s\n' "$det" | sed -n '/^Per-component/,/^$/p' |
      grep -v '^Per-component' | grep -v '^[[:space:]]*component' |
      grep -v '^[[:space:]]*$')"
    if [ -n "$componentes" ]; then
      printf '     Por componente:  nombre / coste fijo / coste cada vez que se usa\n'
      printf '%s\n' "$componentes" | sed 's/^/       /'
    fi
  done <<EOF
$nombres
EOF

  printf '\n   Suma siempre-en-contexto de todos los plugins: ~%s tok  [PROYECTADO]\n' "$(formatea "$total_siempre")"
  if es_entero "$ventana" && [ "$ventana" -gt 0 ]; then
    printf '   Sobre tu ventana medida de %s: %s%%\n' "$(formatea "$ventana")" "$(pct "$total_siempre" "$ventana")"
  fi
  # Se ofrece primero `disable`, que es reversible: desinstalar por ahorrar
  # 84 tokens y perder el plugin es mal negocio, y quien lea esto puede no
  # saber que se puede volver atrás.
  printf '\n   Si alguno no te compensa, desactívalo (reversible con `enable`):\n'
  printf '%s\n' "$nombres" | while IFS= read -r nombre; do
    [ -n "$nombre" ] && printf '     claude plugin disable "%s"\n' "$nombre"
  done
  printf '   Y si ya sabes que no lo quieres, desinstalarlo del todo:\n'
  printf '%s\n' "$nombres" | while IFS= read -r nombre; do
    [ -n "$nombre" ] && printf '     claude plugin uninstall "%s"\n' "$nombre"
  done
}

# --- 4. Servidores MCP -------------------------------------------------------

seccion_mcp() {
  titulo "4. SERVIDORES MCP"
  if ! hay claude; then
    printf '   No se encuentra el ejecutable `claude`: no se puede consultar.\n'
    return
  fi

  salida="$(con_espera claude mcp list 2>/dev/null)"
  if [ -z "$salida" ]; then
    printf '   `claude mcp list` no devolvió nada (o tardó más de %ss).\n' "$espera"
    return
  fi

  # Cada servidor es una línea "nombre: url - estado". Se descarta la
  # cabecera de comprobación de salud.
  servidores="$(printf '%s\n' "$salida" | grep ':' | grep -v 'Checking MCP server health' | sed 's/^[[:space:]]*//')"
  if [ -z "$servidores" ]; then
    printf '   No hay servidores MCP configurados.\n'
    return
  fi

  printf '   Cada servidor conectado mete en contexto la definición de todas\n'
  printf '   sus herramientas, en cada sesión. Claude Code no publica ese coste\n'
  printf '   en tokens por servidor, así que aquí NO se pone una cifra: sería\n'
  printf '   inventada. Lo que sí se puede ver es cuántos tienes.\n\n'

  n=0
  while IFS= read -r linea; do
    [ -n "$linea" ] || continue
    n=$(( n + 1 ))
    printf '     %s\n' "$linea"
  done <<EOF
$servidores
EOF
  n="$(printf '%s\n' "$servidores" | grep -c .)"
  printf '\n   Total: %s servidor(es) MCP.\n' "$n"

  printf '\n   Para quitar el que no uses (nombre entre comillas: los hay con\n'
  printf '   espacios, y sin comillas el comando falla):\n'
  printf '%s\n' "$servidores" | while IFS= read -r linea; do
    nombre="${linea%%:*}"
    [ -n "$nombre" ] && printf '     claude mcp remove "%s"\n' "$nombre"
  done
}

# --- cabecera y montaje ------------------------------------------------------

leer_sesion

printf '======================================================================\n'
printf ' PANEL DE CONTEXTO                                      ahorro-tokens\n'
printf '======================================================================\n'
printf ' Proyecto: %s\n' "$proyecto"
printf ' Fecha:    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '\n Cómo leer las cifras:\n'
printf '   [MEDIDO]      dato real de tu sesión (lo captura la statusLine).\n'
printf '   [PROYECTADO]  lo calcula Claude Code; avisa de que son estimaciones\n'
printf '                 suyas, pero conoce el contenido mejor que nosotros.\n'
printf '   [ESTIMADO]    lo calculamos aquí como caracteres/4. Orientativo.\n'
printf '   Las tres categorías no son comparables: no se suman entre sí.\n'

seccion_sesion
seccion_disco
seccion_plugins
seccion_mcp

printf '\n'
separador
printf ' Recuerda: solo la sección 1 es una medición. El resto son cálculos\n'
printf ' aproximados, útiles para comparar entre sí qué te ocupa más.\n'
separador

exit 0
