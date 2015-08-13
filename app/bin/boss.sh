# Bin, Boss!
# A simple RESTful framework for Bash.
# Version 0.3.2

declare route_match
declare response_headers
declare response_status='200 OK'
declare response_type='text/plain'
declare response_file="/tmp/boss.$RANDOM$$"

# Header
# ---------------------------------------------------------------------------------

status() { response_status=$1; }
header() { head="$1: $2"

  if [[ "$response_headers" ]]
  then response_headers="$response_headers\n$head"
  else response_headers="$head"
  fi
}

# Verbs
# ---------------------------------------------------------------------------------

   get() { boss_route GET $1; }
   put() { boss_route PUT $1; }
  post() { boss_route POST $1; }
delete() { boss_route DELETE $1; }

# Router
# ---------------------------------------------------------------------------------

boss_route() {
  [[ -n "$route_match" ]] && return -1

  local verb="$1"
  local path="$2"
  local regx="$(boss_escape "$path")"
  local -i i

  if [[ "$REQUEST_METHOD" = "$verb" ]] && [[ "$PATH_INFO" =~ $regx ]]; then
  	route_match=true
  	boss_data
  	return 0
  fi
  return -1
}

# Post Data / Query String
# ---------------------------------------------------------------------------------

boss_data() {
  groups=( $(echo $path | grep -o -e ':\w\+' | cut -d: -f2) )
  if [[ -n $groups ]]; then
    for ((i = 1; i < ${#BASH_REMATCH[@]}; i++)); do
      export "${groups[i - 1]}=$(boss_unescape "${BASH_REMATCH[i]}")"
    done
  fi
  if [[ -n $QUERY_STRING ]]; then
    for var in $(echo $QUERY_STRING | tr '&' '\n'); do
      key=$(echo $var | cut -d= -f1)
      val=$(echo $var | cut -d= -f2)
      export "${key}=${val}"
    done
  fi
  if [[ -n "$CONTENT_LENGTH" ]]; then
    read -n $CONTENT_LENGTH REQUEST_BODY
	fi
}

# Escape path (for regex match)
# ---------------------------------------------------------------------------------

boss_escape() {
  local path=$1
  path=$(echo $path \
| sed 's/\./\\./g' \
| sed 's/\+/\\+/g' \
| sed 's/\*/(.*?)/g' \
| sed -E 's/:(\w*)/(.*?)/g')
  echo "^$path\$"
}

# Unescape
# ---------------------------------------------------------------------------------

boss_unescape() {
  local str=$1
  str=${str//+/ }
  str=${str//%/\\x}
  echo -e "$str"
}

# Headers
# ---------------------------------------------------------------------------------

boss_header() {
  if [[ ! $(echo $response_headers | grep 'Status') ]]; then
    header 'Status' "$response_status"
  fi
  if [[ ! $(echo $response_headers | grep 'Content-Type') ]]; then
    header 'Content-Type' "$response_type"
  fi
  if [[ ! $(echo $response_headers | grep 'text/html') ]]; then
    header 'Content-Length' "$(cat $response_file | wc -c)"
  fi
  header 'Cache-control' 'no-cache'
  header 'Connection' 'keep-alive'
  header 'Date' "$(date -u '+%a, %d %b %Y %R:%S GMT')"
  echo -e "$response_headers\r\n"
}

# Reponse
# ---------------------------------------------------------------------------------

boss_response() {
  if [[ -n "$route_match" ]]; then
    boss_header
  	while read -r splendido
  	do echo "$splendido"
  	done < $response_file
  else boss_false
  fi >&5
}

# Not found (404)
# ---------------------------------------------------------------------------------

boss_false() {
  header 'Content-Type' 'text/html'
  boss_header
	cat www/404.html
}

# Done!
# ---------------------------------------------------------------------------------

trap 'boss_response; rm -f $response_file' EXIT
: > $response_file
exec 5>&1
exec > $response_file
