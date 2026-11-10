#!/bin/sh
# Instala o cliente MineServer no Linux.
# Funciona com o Minecraft oficial e com o SKLauncher: os dois leem o mesmo perfil.
set -eu

cd "$(dirname "$0")"
REQ="requirements/client.txt"
MINECRAFT_DIR="${MINECRAFT_DIR:-$HOME/.minecraft}"
SHADERS="${MINESERVER_SHADERS:-}"
SERVER_DIR=""
GAME_DIR_FLAG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --minecraft-dir)
      MINECRAFT_DIR="$2"
      shift 2
      ;;
    --game-dir)
      GAME_DIR_FLAG="$2"
      shift 2
      ;;
    --server-dir)
      SERVER_DIR="$2"
      shift 2
      ;;
    *)
      echo "Uso: bash instalar.sh [--minecraft-dir PASTA] [--game-dir PASTA] [--server-dir PASTA]" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$REQ" ]; then
  echo "Não achei $REQ. Rode este script na pasta baixada do MineServer." >&2
  exit 1
fi

command -v curl >/dev/null 2>&1 || {
  echo "Falta o programa curl." >&2
  exit 1
}
command -v sha1sum >/dev/null 2>&1 || {
  echo "Falta o programa sha1sum." >&2
  exit 1
}

abs_dir() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$(pwd)/$1" ;;
  esac
}

MINECRAFT_DIR="$(abs_dir "$MINECRAFT_DIR")"
if [ -n "$SERVER_DIR" ]; then
  SERVER_DIR="$(abs_dir "$SERVER_DIR")"
  if [ ! -d "$SERVER_DIR" ]; then
    echo "Não achei a pasta do servidor: $SERVER_DIR" >&2
    exit 1
  fi
fi
if [ -n "$GAME_DIR_FLAG" ]; then
  GAME_DIR_FLAG="$(abs_dir "$GAME_DIR_FLAG")"
fi

meta() {
  key="$1"
  sed -n "s/^# ${key} //p" "$REQ" | head -n 1
}

MINECRAFT_VERSION="$(meta minecraft)"
LOADER_VERSION="$(meta loader_version)"
PROFILE_NAME="$(meta profile)"
PROFILE_ID="$(meta profile_id)"
GAME_DIR_NAME="$(meta game_dir)"
MEMORY="$(meta memory)"
VERSION_ID="fabric-loader-${LOADER_VERSION}-${MINECRAFT_VERSION}"

if [ -z "$MINECRAFT_VERSION" ] || [ -z "$LOADER_VERSION" ] || [ -z "$PROFILE_ID" ]; then
  echo "A ficha requirements/client.txt está incompleta." >&2
  exit 1
fi

profile_game_dir() {
  profiles="$1"
  want="$2"
  [ -f "$profiles" ] || return 1
  awk -v want="$want" '
    function braces(s,    i, c, n) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "{") n++
        else if (c == "}") n--
      }
      return n
    }
    function grab(s, key,    rest, q) {
      if (match(s, "\"" key "\"[[:space:]]*:[[:space:]]*\"")) {
        rest = substr(s, RSTART + RLENGTH)
        q = index(rest, "\"")
        if (q > 1) return substr(rest, 1, q - 1)
      }
      return ""
    }
    BEGIN { in_profiles = 0; depth = 0; capture = 0; pname = ""; pdir = "" }
    {
      if (!in_profiles) {
        if ($0 ~ /"profiles"[[:space:]]*:[[:space:]]*\{/) {
          in_profiles = 1
          depth = braces($0)
        }
        next
      }
      delta = braces($0)
      if (!capture && depth == 1 && delta > 0) {
        capture = 1
        pname = ""
        pdir = ""
      }
      if (capture) {
        n = grab($0, "name")
        if (n != "") pname = n
        d = grab($0, "gameDir")
        if (d != "") pdir = d
      }
      depth += delta
      if (capture && depth <= 1) {
        if (pname == want && pdir != "") {
          print pdir
          exit 0
        }
        capture = 0
      }
    }
  ' "$profiles"
}

ask_shaders() {
  if [ -n "$SHADERS" ]; then
    return 0
  fi
  printf "Quer instalar os shaders? O jogo fica mais bonito e mais pesado. Digite s para sim, ou Enter para não: "
  read -r SHADERS || SHADERS=""
}

want_shaders() {
  case "$SHADERS" in
    s|S|sim|Sim|SIM) return 0 ;;
    *) return 1 ;;
  esac
}

ask_shaders

if [ -n "$GAME_DIR_FLAG" ]; then
  GAME_DIR="$GAME_DIR_FLAG"
else
  found="$(profile_game_dir "$MINECRAFT_DIR/launcher_profiles.json" "$PROFILE_NAME" || true)"
  if [ -n "$found" ]; then
    GAME_DIR="$found"
  else
    GAME_DIR="$MINECRAFT_DIR/$GAME_DIR_NAME"
  fi
fi
mkdir -p "$GAME_DIR/mods" "$GAME_DIR/shaderpacks" \
  "$MINECRAFT_DIR/versions/$VERSION_ID"
if [ -n "$SERVER_DIR" ]; then
  mkdir -p "$SERVER_DIR/mods"
fi

hash_ok() {
  local file sum
  file="$1"
  sum="$2"
  [ -n "$sum" ] && [ "$sum" != "-" ] && [ -f "$file" ] && echo "$sum  $file" | sha1sum -c - >/dev/null 2>&1
}

download() {
  local url dest sum alt
  url="$1"
  dest="$2"
  sum="$3"
  alt="${4:-}"
  if hash_ok "$dest" "$sum" || hash_ok "$dest" "$alt"; then
    echo "já está certo: $(basename "$dest")"
    return 0
  fi
  echo "baixando $(basename "$dest")"
  curl -fL --retry 3 --retry-delay 2 -A "MineServer-installer" -o "$dest.partial" "$url"
  if ! echo "$sum  $dest.partial" | sha1sum -c - >/dev/null 2>&1; then
    rm -f "$dest.partial"
    echo "O arquivo $(basename "$dest") não confere com a ficha. O que já estava no lugar ficou." >&2
    exit 1
  fi
  mv "$dest.partial" "$dest"
}

patch_loader() {
  local jar needed tmp
  jar="$1"
  needed="$2"
  command -v unzip >/dev/null 2>&1 || {
    echo "Falta o programa unzip para ajustar o Passive Skill Tree." >&2
    exit 1
  }
  command -v zip >/dev/null 2>&1 || {
    echo "Falta o programa zip para ajustar o Passive Skill Tree." >&2
    exit 1
  }
  tmp="$(mktemp -d)"
  unzip -p "$jar" fabric.mod.json > "$tmp/fabric.mod.json"
  if ! grep -q '"fabricloader": "0.19.3"' "$tmp/fabric.mod.json"; then
    echo "Não achei a trava do Fabric Loader dentro de $(basename "$jar")." >&2
    rm -rf "$tmp"
    exit 1
  fi
  sed "s/\"fabricloader\": \"0.19.3\"/\"fabricloader\": \"$needed\"/" "$tmp/fabric.mod.json" > "$tmp/patched.json"
  mv "$tmp/patched.json" "$tmp/fabric.mod.json"
  (
    cd "$tmp"
    zip -q "$jar" fabric.mod.json
  )
  rm -rf "$tmp"
}

install_row() {
  local base side filename sum url dest patch alt target
  base="$1"
  side="$2"
  filename="$3"
  sum="$4"
  url="$5"
  dest="$6"
  patch="$7"
  alt="$8"
  if [ "$side" = "shader" ] && ! want_shaders; then
    return 0
  fi
  case "$side" in
    required|shader) ;;
    *)
      echo "Lado desconhecido na ficha: $side" >&2
      exit 1
      ;;
  esac
  case "$url" in
    https://*) ;;
    *)
      echo "A ficha tem um endereço que não é https: $filename" >&2
      exit 1
      ;;
  esac
  target="$base/$dest/$filename"
  mkdir -p "$base/$dest"
  download "$url" "$target" "$sum" "$alt"
  if [ "$patch" != "-" ] && ! hash_ok "$target" "$alt"; then
    patch_loader "$target" "$patch"
  fi
}

# shellcheck disable=SC2034
while IFS="$(printf '\t')" read -r side id name filename sum url dest patch origin server_sha1 page; do
  [ -n "$side" ] || continue
  case "$side" in
    \#*) continue ;;
  esac
  install_row "$GAME_DIR" "$side" "$filename" "$sum" "$url" "$dest" "$patch" "$server_sha1"
  if [ -n "$SERVER_DIR" ] && [ "$origin" = "server" ]; then
    install_row "$SERVER_DIR" "$side" "$filename" "$sum" "$url" "$dest" "$patch" "$server_sha1"
  fi
done < "$REQ"

FABRIC_JSON="$MINECRAFT_DIR/versions/$VERSION_ID/$VERSION_ID.json"
echo "baixando o perfil Fabric $VERSION_ID"
curl -fL --retry 3 -A "MineServer-installer" \
  -o "$FABRIC_JSON" \
  "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${LOADER_VERSION}/profile/json"

PROFILES="$MINECRAFT_DIR/launcher_profiles.json"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
if [ ! -f "$PROFILES" ]; then
  cat > "$PROFILES" <<EOF
{
  "profiles": {
    "$PROFILE_ID": {
      "created": "$STAMP",
      "gameDir": "$GAME_DIR",
      "icon": "Enchanting_Table",
      "javaArgs": "$MEMORY",
      "lastUsed": "$STAMP",
      "lastVersionId": "$VERSION_ID",
      "name": "$PROFILE_NAME",
      "type": "custom"
    }
  },
  "selectedProfile": "$PROFILE_ID",
  "version": 4
}
EOF
elif grep -q "\"name\"[[:space:]]*:[[:space:]]*\"$PROFILE_NAME\"" "$PROFILES"; then
  echo "O perfil $PROFILE_NAME já existe. Atualizei os mods em $GAME_DIR."
else
  tmp="$(mktemp)"
  awk -v id="$PROFILE_ID" -v stamp="$STAMP" -v game="$GAME_DIR" -v mem="$MEMORY" -v ver="$VERSION_ID" -v name="$PROFILE_NAME" '
    BEGIN { inserted = 0 }
    !inserted && $0 ~ /"profiles"[[:space:]]*:[[:space:]]*\{/ {
      print
      print "    \"" id "\": {"
      print "      \"created\": \"" stamp "\","
      print "      \"gameDir\": \"" game "\","
      print "      \"icon\": \"Enchanting_Table\","
      print "      \"javaArgs\": \"" mem "\","
      print "      \"lastUsed\": \"" stamp "\","
      print "      \"lastVersionId\": \"" ver "\","
      print "      \"name\": \"" name "\","
      print "      \"type\": \"custom\""
      print "    },"
      inserted = 1
      next
    }
    { print }
    END {
      if (!inserted) exit 2
    }
  ' "$PROFILES" > "$tmp" || {
    echo "Não consegui acrescentar o perfil no launcher. Os mods estão em $GAME_DIR" >&2
    rm -f "$tmp"
    exit 1
  }
  mv "$tmp" "$PROFILES"
fi

echo
echo "Pronto."
echo "Abra o Minecraft oficial ou o SKLauncher e escolha o perfil $PROFILE_NAME."
echo "O nome que você usa no launcher é o nome dentro do jogo. Use o seu."
if want_shaders; then
  echo "Shaders instalados. No jogo, o pacote é o Complementary."
else
  echo "Shaders não instalados."
fi
if [ -n "$SERVER_DIR" ]; then
  echo "Mods do servidor atualizados em $SERVER_DIR/mods."
fi
echo "O endereço do servidor o grupo manda no chat."
