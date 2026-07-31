#!/usr/bin/env bash
# statusline.sh — captura el payload que Claude Code pasa a la statusLine y
# pinta una línea de estado mínima.
#
# Claude Code ejecuta este script después de cada turno y le entrega por stdin
# un JSON con, entre otros campos:
#
#   model.display_name
#   workspace.current_dir
#   session_id
#   cost.total_cost_usd
#   context_window { context_window_size, used_percentage, remaining_percentage,
#                    current_usage { input_tokens, output_tokens,
#                                    cache_creation_input_tokens,
#                                    cache_read_input_tokens } }
#
# El payload íntegro se vuelca a ~/.cache/ahorro-tokens/<session_id>.json para
# que el panel bajo demanda (fase 2) pueda leer cifras MEDIDAS en vez de
# estimarlas. La antigüedad del dato es la fecha de modificación del fichero.
#
# AVISO SOBRE LOS CAMPOS ACUMULADOS
# context_window.total_input_tokens y .total_output_tokens son acumulados de
# toda la sesión, no el contenido actual de la ventana, y no se corrigen tras
# un autocompact (issue #13783: statuslines reportando 169% cuando /context
# mostraba 40%). Aquí NO se usan. La ocupación se calcula solo con entrada:
#
#   input_tokens + cache_creation_input_tokens + cache_read_input_tokens
#
# que es la fórmula que cuadra con used_percentage.
#
# current_usage es null antes de la primera llamada a la API de la sesión y
# otra vez justo después de /compact: ese caso se trata explícitamente.
#
# Reglas de robustez: este script nunca debe dejar la barra en blanco ni
# escribir un error en ella. Por eso no usa `set -e` ni `set -u` (un fallo
# aislado no debe abortar), manda stderr a /dev/null y siempre sale con 0.

exec 2>/dev/null

# Locale fijo: que sed/grep y el %.1f de printf se comporten igual en
# cualquier máquina (con LC_NUMERIC español, printf escribiría "22,6").
export LC_ALL=C

linea_por_defecto="ahorro-tokens: sin datos de sesión"

# --- 1. Leer stdin -----------------------------------------------------------

payload="$(cat)"

if [ -z "$payload" ]; then
  printf '%s\n' "$linea_por_defecto"
  exit 0
fi

# --- 2. Volcar el payload al caché ------------------------------------------

volcar_cache() {
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ahorro-tokens"
  [ -n "$HOME" ] || return 0

  # Solo se cachea lo que al menos parece JSON: si llega basura, más vale
  # dejar el volcado anterior intacto que dejar a la fase 2 leyendo ruido.
  case "$payload" in '{'*) ;; *) return 0 ;; esac

  mkdir -p "$cache_dir" || return 0

  # El session_id va en el nombre del fichero: dos sesiones simultáneas en
  # proyectos distintos no se pisan. Se sanea para que no pueda salirse del
  # directorio de caché.
  # Se descarta todo lo que no sea [A-Za-z0-9._-] (las barras de un
  # "../../otro/sitio" se vuelven "_", así que no hay salto de directorio) y
  # se quitan los puntos iniciales, para no acabar generando ficheros ocultos.
  sesion="$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | sed 's/^\.*//' | cut -c1-64)"
  [ -n "$sesion" ] || sesion="sin-sesion"

  destino="$cache_dir/$sesion.json"
  tmp="$destino.tmp.$$"

  printf '%s' "$payload" > "$tmp" || return 0
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return 0; }

  # "ultima.json" apunta siempre al volcado más reciente, para poder
  # localizarlo sin saber el session_id. Enlace si el sistema lo permite,
  # copia si no.
  ln -sfn "$destino" "$cache_dir/ultima.json" 2>/dev/null ||
    cp -f "$destino" "$cache_dir/ultima.json" 2>/dev/null
  return 0
}

# --- 3. Extraer los campos ---------------------------------------------------
#
# Con jq si está disponible; si no, parseo POSIX simple. Ninguna dependencia
# nueva que haya que instalar.

modelo=""
tam_ventana=""
tokens=""
pct_declarado=""
sesion_id=""

leer_con_jq() {
  printf '%s' "$payload" | jq -r '
    def n(x): if (x | type) == "number" then x else 0 end;
    [ (.model.display_name // ""),
      (.context_window.context_window_size // "" | tostring),
      (if .context_window.current_usage == null then ""
       else ( n(.context_window.current_usage.input_tokens)
            + n(.context_window.current_usage.cache_creation_input_tokens)
            + n(.context_window.current_usage.cache_read_input_tokens)
            ) | tostring
       end),
      (.context_window.used_percentage // "" | tostring),
      (.session_id // "")
    ]
    # Separador \u001f (unit separator) en vez de tabulador: el tabulador es
    # espacio en blanco para IFS, y bash colapsa los delimitadores en blanco
    # consecutivos, con lo que un campo vacío desplazaría todos los siguientes
    # (un current_usage null acababa leyéndose como "0 tokens, 0.0%").
    | join("\u001f")
  ' 2>/dev/null
}

# Extrae el valor numérico de una clave exacta. Se trocea por comas y llaves
# para que cada clave quede en su propia línea: así "input_tokens" no captura
# "cache_read_input_tokens".
num_de() {
  printf '%s' "$payload" | tr ',{}' '\n\n\n' |
    sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\([0-9][0-9.]*\).*/\1/p" |
    head -n1
}

texto_de() {
  printf '%s' "$payload" | tr ',{}' '\n\n\n' |
    sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
    head -n1
}

if command -v jq >/dev/null 2>&1; then
  IFS=$(printf '\037') read -r modelo tam_ventana tokens pct_declarado sesion_id <<EOF
$(leer_con_jq)
EOF
else
  modelo="$(texto_de display_name)"
  sesion_id="$(texto_de session_id)"
  tam_ventana="$(num_de context_window_size)"
  pct_declarado="$(num_de used_percentage)"

  # current_usage null (antes de la primera llamada a la API, o justo después
  # de /compact): no hay tokens que sumar, y hay que decirlo, no inventarlo.
  if printf '%s' "$payload" | tr -d ' \n\r\t' | grep -q '"current_usage":null'; then
    tokens=""
  else
    entrada="$(num_de input_tokens)"
    creacion="$(num_de cache_creation_input_tokens)"
    lectura="$(num_de cache_read_input_tokens)"
    if [ -n "$entrada$creacion$lectura" ]; then
      tokens=$(( ${entrada:-0} + ${creacion:-0} + ${lectura:-0} ))
    fi
  fi
fi

volcar_cache "$sesion_id"

# --- 4. Componer la línea ----------------------------------------------------

es_entero() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

# 200000 -> 200k ; 45231 -> 45.2k ; 812 -> 812
formatea() {
  n="$1"
  es_entero "$n" || { printf '%s' "$n"; return; }
  if [ "$n" -lt 1000 ]; then
    printf '%s' "$n"
  elif [ $(( n % 1000 )) -eq 0 ]; then
    printf '%sk' $(( n / 1000 ))
  else
    d=$(( n / 100 ))
    printf '%s.%sk' $(( d / 10 )) $(( d % 10 ))
  fi
}

partes=""
[ -n "$modelo" ] && partes="$modelo"

# REGLA: sin tokens medidos no se enseña porcentaje, nunca. Cuando
# current_usage es null, used_percentage llega a 0, y un "0%" en la barra se
# lee como "ventana vacía" cuando en realidad significa "todavía no hay
# medida". Solo se usa used_percentage como complemento de unos tokens ya
# medidos, jamás como sustituto.
if es_entero "$tokens" && es_entero "$tam_ventana" && [ "$tam_ventana" -gt 0 ]; then
  # Porcentaje con un decimal, aritmética entera (sin bc ni awk), redondeado
  # al más cercano para que barra y panel den la misma cifra.
  p=$(( ( tokens * 1000 + tam_ventana / 2 ) / tam_ventana ))
  ocupacion="$(formatea "$tokens")/$(formatea "$tam_ventana") tokens ($(( p / 10 )).$(( p % 10 ))%)"
elif es_entero "$tokens" && [ -n "$pct_declarado" ]; then
  # Hay tokens pero no tamaño de ventana: el porcentaje solo puede venir del
  # que declara Claude Code.
  ocupacion="$(formatea "$tokens") tokens ($(printf '%.1f' "$pct_declarado" 2>/dev/null || printf '%s' "$pct_declarado")% de la ventana)"
elif es_entero "$tokens"; then
  ocupacion="$(formatea "$tokens") tokens"
else
  ocupacion="ventana: sin medir aún"
fi

if [ -n "$partes" ]; then
  printf '%s | %s\n' "$partes" "$ocupacion"
else
  printf '%s\n' "$ocupacion"
fi

exit 0
