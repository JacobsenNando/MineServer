#!/bin/sh
# Instala o cliente MineServer no Linux.
# Funciona com o Minecraft oficial e com o SKLauncher: os dois leem o mesmo perfil.
# O mesmo fluxo existe em instalar.ps1. Instalar.bat abre esse script no Windows.
set -eu

cd "$(dirname "$0")"
ROOT=$(pwd)

minecraft_client_open() {
  ps -A -o args= 2>/dev/null | grep -E 'KnotClient|net\.minecraft\.client\.main\.Main' | grep -v grep >/dev/null 2>&1
}

trees_match() {
  command -v diff >/dev/null 2>&1 || return 1
  diff -rq --exclude .mineserver-rev --exclude .git "$1" "$2" >/dev/null 2>&1
}

update_from_github() {
  if [ -n "${MINESERVER_SKIP_UPDATE:-}" ]; then
    return 0
  fi
  if [ -d .git ]; then
    return 0
  fi
  if minecraft_client_open; then
    echo "O Minecraft está aberto. Fecha ele por completo e roda o instalador de novo. Com o jogo aberto a atualização não entra." >&2
    exit 1
  fi
  command -v curl >/dev/null 2>&1 || {
    echo "Não achei o curl. Sigo com a cópia que já está aqui."
    return 0
  }
  command -v unzip >/dev/null 2>&1 || {
    echo "Não achei o unzip. Sigo com a cópia que já está aqui."
    return 0
  }
  body=$(curl -fsSL --retry 3 -A "MineServer-installer" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/JacobsenNando/MineServer/commits/master" || true)
  sha=$(printf '%s\n' "$body" | grep -o '"sha": *"[0-9a-f]\{40\}"' | head -n 1 | grep -o '[0-9a-f]\{40\}' || true)
  if [ -z "$sha" ]; then
    echo "Não consegui consultar o GitHub. Sigo com a cópia que já está aqui."
    return 0
  fi
  local_rev=""
  if [ -f .mineserver-rev ]; then
    local_rev=$(tr -d '[:space:]' < .mineserver-rev)
  fi
  if [ "$local_rev" = "$sha" ]; then
    return 0
  fi
  echo "Consultando a versão no GitHub."
  tmp=$(mktemp -d)
  if ! curl -fsSL --retry 3 -A "MineServer-installer" -o "$tmp/master.zip" \
    "https://github.com/JacobsenNando/MineServer/archive/refs/heads/master.zip"; then
    echo "Não consegui baixar a versão nova. Sigo com a cópia que já está aqui."
    rm -rf "$tmp"
    return 0
  fi
  if ! unzip -q "$tmp/master.zip" -d "$tmp/src"; then
    echo "O zip novo veio incompleto. Sigo com a cópia que já está aqui."
    rm -rf "$tmp"
    return 0
  fi
  src="$tmp/src/MineServer-master"
  if [ ! -f "$src/instalar.sh" ]; then
    echo "O zip novo não trouxe o instalador. Sigo com a cópia que já está aqui."
    rm -rf "$tmp"
    return 0
  fi
  if trees_match "$src" .; then
    printf '%s\n' "$sha" > .mineserver-rev
    rm -rf "$tmp"
    echo "Esta pasta já está na versão nova."
    return 0
  fi
  cp -a "$src"/. .
  printf '%s\n' "$sha" > .mineserver-rev
  rm -rf "$tmp"
  echo "Pasta atualizada. Continuo a instalação com a versão nova."
  MINESERVER_SKIP_UPDATE=1 exec "$ROOT/instalar.sh" "$@"
}

update_from_github "$@"

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

need_zip() {
  command -v unzip >/dev/null 2>&1 || {
    echo "Falta o programa unzip." >&2
    exit 1
  }
  command -v zip >/dev/null 2>&1 || {
    echo "Falta o programa zip." >&2
    exit 1
  }
}

patch_loader() {
  local jar needed tmp
  jar="$1"
  needed="$2"
  need_zip
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

patch_class() {
  local jar entry class tmp current
  jar="$1"
  entry="$2"
  class="$3"
  [ -f "$class" ] || {
    echo "Falta $class para corrigir o mod." >&2
    exit 1
  }
  if unzip -l "$jar" "$entry" | grep -q "$(basename "$entry")"; then
    current="$(mktemp)"
    unzip -p "$jar" "$entry" > "$current"
    if cmp -s "$current" "$class"; then
      rm -f "$current"
      return 0
    fi
    rm -f "$current"
  fi
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/$(dirname "$entry")"
  cp "$class" "$tmp/$entry"
  touch -t 198001010000 "$tmp/$entry"
  (
    cd "$tmp"
    zip -q -X "$jar" "$entry"
  )
  rm -rf "$tmp"
  current="$(mktemp)"
  unzip -p "$jar" "$entry" > "$current"
  if ! cmp -s "$current" "$class"; then
    rm -f "$current"
    echo "A correção não entrou em $(basename "$jar")." >&2
    exit 1
  fi
  rm -f "$current"
}

# A camada do meio do peito da armadura divina não desenha mais o brilho forçado.
# Em primeira pessoa, a armadura do próprio jogador não desenha por cima da câmera.
patch_immersive_armors() {
  local jar
  jar="$1"
  need_zip
  case "$jar" in
    /*) ;;
    *) jar="$(pwd)/$jar" ;;
  esac
  patch_class "$jar" \
    "immersive_armors/ItemsClient.class" \
    "patches/immersive_armors/ItemsClient.class"
  patch_class "$jar" \
    "immersive_armors/mixin/MixinHumanoidArmorLayer.class" \
    "patches/immersive_armors/mixin/MixinHumanoidArmorLayer.class"
}

# A barra de progresso fica no canto inferior direito, com 80 pixels de largura.
patch_skill_hud() {
  local jar
  jar="$1"
  need_zip
  case "$jar" in
    /*) ;;
    *) jar="$(pwd)/$jar" ;;
  esac
  patch_class "$jar" \
    "daripher/skilltree/client/hud/SkillProgressHudOverlay.class" \
    "patches/skilltree/SkillProgressHudOverlay.class"
  patch_class "$jar" \
    "daripher/skilltree/client/SkillTreeModClient.class" \
    "patches/skilltree/SkillTreeModClient.class"
}

retire_old_viewers() {
  local base name
  base="$1"
  for name in RoughlyEnoughItems-26.2.820.jar architectury-fabric-21.1.12.jar; do
    if [ -f "$base/mods/$name" ]; then
      rm -f "$base/mods/$name"
      echo "Removi $name."
    fi
  done
}

copy_jei_addon() {
  local dest src
  dest="$1"
  src="bundled/client/mineserver-jei-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/mods"
  cp "$src" "$dest/mods/mineserver-jei-1.0.0.jar"
  echo "MineServer JEI copiado para $dest/mods."
}

copy_atributos() {
  local dest src
  dest="$1"
  src="bundled/client/mineserver-atributos-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/mods"
  cp "$src" "$dest/mods/mineserver-atributos-1.0.0.jar"
  echo "MineServer Atributos copiado para $dest/mods."
}

copy_encantamentos() {
  local dest src
  dest="$1"
  src="bundled/client/mineserver-encantamentos-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/mods"
  cp "$src" "$dest/mods/mineserver-encantamentos-1.0.0.jar"
  echo "MineServer Encantamentos copiado para $dest/mods."
}

copy_class_mod() {
  local dest src
  dest="$1"
  src="bundled/server/mineserver-classes-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/mods"
  cp "$src" "$dest/mods/mineserver-classes-1.0.0.jar"
  echo "MineServer Classes copiado para $dest/mods."
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
  if [ "$filename" = "PassiveSkillTree-Fabric-26.2-0.7.6+c.jar" ]; then
    patch_skill_hud "$target"
  fi
  if [ "$filename" = "immersive_armors-1.8.2+26.2-fabric.jar" ]; then
    patch_immersive_armors "$target"
  fi
}

retire_old_viewers "$GAME_DIR"
if [ -n "$SERVER_DIR" ]; then
  retire_old_viewers "$SERVER_DIR"
fi

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

copy_client_config() {
  local dest src
  dest="$1"
  src="bundled/config/trinkets.json"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/config"
  cp "$src" "$dest/config/trinkets.json"
  echo "Coluna de berloques gravada em $dest/config/trinkets.json"
}

# O pacote fica por último em resourcePacks: no 26.2, o último da lista cobre o anterior.
# lang:pt_br faz o jogo ler assets/*/lang/pt_br.json desse pacote.
copy_language_pack() {
  local dest src options tmp
  dest="$1"
  src="bundled/resourcepacks/mineserver-idioma"
  options="$dest/options.txt"
  tmp="$options.partial"
  [ -f "$src/pack.mcmeta" ] || {
    echo "Falta o pacote de idioma em $src." >&2
    exit 1
  }
  if minecraft_client_open; then
    echo "O Minecraft está aberto. Fecha ele por completo e roda o instalador de novo. Com o jogo aberto a tradução não fica ligada." >&2
    exit 1
  fi
  mkdir -p "$dest/resourcepacks"
  rm -rf "$dest/resourcepacks/mineserver-idioma"
  cp -R "$src" "$dest/resourcepacks/mineserver-idioma"
  if [ -f "$options" ]; then
    awk '
      function rebuilt(line, want, keep,    key, body, n, i, parts, item, out) {
        key = line
        sub(/:.*/, "", key)
        body = line
        sub(/^[^:]*:[[:space:]]*\[/, "", body)
        sub(/\][[:space:]]*$/, "", body)
        n = split(body, parts, ",")
        out = ""
        for (i = 1; i <= n; i++) {
          item = parts[i]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
          if (item == "" || item == want) continue
          out = out (out == "" ? "" : ",") item
        }
        if (keep && out == "") out = "\"vanilla\""
        if (keep) out = out (out == "" ? "" : ",") want
        return key ":[" out "]"
      }
      BEGIN { pack = "\"file/mineserver-idioma\"" }
      {
        sub(/\r$/, "")
        if ($0 ~ /^resourcePacks:/) {
          seen_packs = 1
          print rebuilt($0, pack, 1)
          next
        }
        if ($0 ~ /^incompatibleResourcePacks:/) {
          print rebuilt($0, pack, 0)
          next
        }
        if ($0 ~ /^lang:/) {
          seen_lang = 1
          print "lang:pt_br"
          next
        }
        print
      }
      END {
        if (!seen_packs) print "resourcePacks:[\"vanilla\"," pack "]"
        if (!seen_lang) print "lang:pt_br"
      }
    ' "$options" > "$tmp" || {
      rm -f "$tmp"
      echo "Não consegui ligar a tradução em $options." >&2
      exit 1
    }
    mv "$tmp" "$options"
  else
    printf '%s\n' \
      'lang:pt_br' \
      'resourcePacks:["vanilla","file/mineserver-idioma"]' \
      'incompatibleResourcePacks:[]' > "$options"
  fi
  echo "Tradução ligada em $dest. A árvore de habilidades abre em português."
}

copy_server_bundle() {
  local dest src
  dest="$1"
  src="bundled/server/mineserver-classes-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  mkdir -p "$dest/mods" "$dest/config"
  cp "bundled/config/trinkets.json" "$dest/config/trinkets.json"
  cp "bundled/config/icys-better-horses.json" "$dest/config/icys-better-horses.json"
  cp "$src" "$dest/mods/mineserver-classes-1.0.0.jar"
  echo "MineServer Classes copiado para $dest/mods."
  src="bundled/server/mineserver-zoacao-1.0.0.jar"
  [ -f "$src" ] || {
    echo "Falta $src." >&2
    exit 1
  }
  cp "$src" "$dest/mods/mineserver-zoacao-1.0.0.jar"
  echo "MineServer Zoeira copiado para $dest/mods."
}

copy_client_config "$GAME_DIR"
copy_language_pack "$GAME_DIR"
copy_jei_addon "$GAME_DIR"
copy_atributos "$GAME_DIR"
copy_encantamentos "$GAME_DIR"
copy_class_mod "$GAME_DIR"
if [ -n "$SERVER_DIR" ]; then
  copy_server_bundle "$SERVER_DIR"
fi

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
  echo "A trava de classe está em $SERVER_DIR/mods/mineserver-classes-1.0.0.jar."
  echo "A zoeira de morte está em $SERVER_DIR/mods/mineserver-zoacao-1.0.0.jar."
fi
echo "O menu de caminhos usa $GAME_DIR/mods/mineserver-classes-1.0.0.jar. Feche o Minecraft por completo para carregar."
echo "Anel, livro e mochila ficam na coluna ao lado do personagem. Feche o jogo e abra de novo se ele estiver aberto."
echo "O endereço do servidor o grupo manda no chat."
