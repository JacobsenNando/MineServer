#!/bin/sh
# Instala o cliente MineServer no Linux.
# Funciona com o Minecraft oficial e com o SKLauncher: os dois leem o mesmo perfil.
set -eu

cd "$(dirname "$0")"
REQ="requirements/client.txt"
MINECRAFT_DIR="${MINECRAFT_DIR:-$HOME/.minecraft}"
SHADERS="${MINESERVER_SHADERS:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --minecraft-dir)
      MINECRAFT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Uso: bash instalar.sh [--minecraft-dir PASTA]" >&2
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

case "$MINECRAFT_DIR" in
  /*) ;;
  *) MINECRAFT_DIR="$(pwd)/$MINECRAFT_DIR" ;;
esac

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

GAME_DIR="$MINECRAFT_DIR/$GAME_DIR_NAME"
mkdir -p "$GAME_DIR/mods" "$GAME_DIR/shaderpacks" \
  "$MINECRAFT_DIR/versions/$VERSION_ID"

download() {
  url="$1"
  dest="$2"
  sum="$3"
  if [ -f "$dest" ] && echo "$sum  $dest" | sha1sum -c - >/dev/null 2>&1; then
    echo "já está certo: $(basename "$dest")"
    return 0
  fi
  echo "baixando $(basename "$dest")"
  curl -fL --retry 3 --retry-delay 2 -A "MineServer-installer" -o "$dest.partial" "$url"
  mv "$dest.partial" "$dest"
  if ! echo "$sum  $dest" | sha1sum -c - >/dev/null 2>&1; then
    echo "O arquivo $(basename "$dest") não confere com a ficha. Nada foi deixado no lugar." >&2
    rm -f "$dest"
    exit 1
  fi
}

patch_loader() {
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
  side="$1"
  filename="$2"
  sum="$3"
  url="$4"
  dest="$5"
  patch="$6"
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
  target="$GAME_DIR/$dest/$filename"
  mkdir -p "$GAME_DIR/$dest"
  download "$url" "$target" "$sum"
  if [ "$patch" != "-" ]; then
    patch_loader "$target" "$patch"
  fi
}

# shellcheck disable=SC2034
while IFS="$(printf '\t')" read -r side id name filename sum url dest patch origin server_sha1 page; do
  [ -n "$side" ] || continue
  case "$side" in
    \#*) continue ;;
  esac
  install_row "$side" "$filename" "$sum" "$url" "$dest" "$patch"
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
  echo "O perfil $PROFILE_NAME já existe. Atualizei os mods dessa instalação."
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
echo "O endereço do servidor o grupo manda no chat."
