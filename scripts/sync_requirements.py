#!/usr/bin/env python3
"""Atualiza requirements/client.txt a partir da pasta mods do servidor.

Quem vai jogar não roda este script. Ele fica na máquina de quem cuida do
servidor. Os mods só de cliente e os shaders permanecem na ficha.
"""

from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIREMENTS = ROOT / "requirements" / "client.txt"
HUMAN = ROOT / "requirements" / "REQUISITOS.md"
META_KEYS = (
    "minecraft",
    "loader",
    "loader_version",
    "java",
    "profile",
    "profile_id",
    "game_dir",
    "memory",
    "server_only",
)
COLUMNS = (
    "side",
    "id",
    "name",
    "filename",
    "sha1",
    "url",
    "dest",
    "patch",
    "origin",
    "server_sha1",
    "page",
)
FORBIDDEN = ("ocid1.", "BEGIN OPENSSH", "BEGIN RSA", "gho_", ".pem")


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def sha1_file(path: Path) -> str:
    digest = hashlib.sha1()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_mod(path: Path) -> tuple[str, str]:
    with zipfile.ZipFile(path) as archive:
        meta = json.loads(archive.read("fabric.mod.json"))
    mod_id = meta.get("id")
    name = meta.get("name") or mod_id
    if not mod_id or not name:
        fail(f"{path.name} não tem id no fabric.mod.json")
    return mod_id, name


def load(path: Path) -> tuple[dict[str, str], list[dict[str, str]]]:
    meta: dict[str, str] = {}
    rows: list[dict[str, str]] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not raw.strip():
            continue
        if raw.startswith("#"):
            body = raw[1:].strip()
            key, _, value = body.partition(" ")
            if key in META_KEYS and value:
                meta[key] = value.strip()
            continue
        cols = raw.split("\t")
        if len(cols) != len(COLUMNS):
            fail(f"linha {line_number} tem {len(cols)} colunas, esperava {len(COLUMNS)}")
        rows.append(dict(zip(COLUMNS, cols)))
    missing = [key for key in META_KEYS if key not in meta]
    if missing:
        fail("faltam campos na ficha: " + ", ".join(missing))
    return meta, rows


def modrinth_by_hash(hashes: list[str]) -> dict:
    if not hashes:
        return {}
    payload = json.dumps({"algorithm": "sha1", "hashes": hashes}).encode()
    request = urllib.request.Request(
        "https://api.modrinth.com/v2/version_files",
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "MineServer-requirements"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode())


def page_for(project_id: str, dest: str) -> str:
    kind = "shader" if dest == "shaderpacks" else "mod"
    return f"https://modrinth.com/{kind}/{project_id}"


def apply_version(row: dict[str, str], version: dict, file_sha1: str) -> None:
    primary = next(item for item in version["files"] if item.get("primary"))
    row["filename"] = primary["filename"]
    row["sha1"] = file_sha1
    row["url"] = primary["url"]
    row["server_sha1"] = "-"
    row["patch"] = "-"
    row["page"] = page_for(version["project_id"], row["dest"])
    row["origin"] = "server"
    row["side"] = "required"
    row["dest"] = "mods"


def write_requirements(meta: dict[str, str], rows: list[dict[str, str]]) -> None:
    rows.sort(key=lambda row: (row["side"] != "required", row["origin"] != "server", row["name"].lower()))
    lines = [
        "# Ficha do cliente MineServer",
        "# Quem vai jogar usa o instalador. O mundo e os arquivos do servidor não estão aqui.",
    ]
    for key in META_KEYS:
        lines.append(f"# {key} {meta[key]}")
    lines.append("# columns\t" + "\t".join(COLUMNS))
    for row in rows:
        lines.append("\t".join(row[column] for column in COLUMNS))
    text = "\n".join(lines) + "\n"
    for marker in FORBIDDEN:
        if marker in text:
            fail(f"a ficha ficaria com informação que não pode ir para o GitHub ({marker})")
    for row in rows:
        if not row["url"].startswith("https://"):
            fail(f"URL inválida em {row['id']}")
    REQUIREMENTS.write_text(text, encoding="utf-8")

    required = [row for row in rows if row["side"] == "required"]
    shaders = [row for row in rows if row["side"] == "shader"]
    body = [
        "# Requisitos do cliente MineServer",
        "",
        f"Minecraft Java **{meta['minecraft']}**, Fabric Loader **{meta['loader_version']}**, Java **{meta['java']}**.",
        "",
        "O instalador baixa esta lista. O servidor não está neste repositório.",
        "",
        "## Entram sempre",
        "",
    ]
    body.extend(f"- [{row['name']}]({row['page']}) `{row['filename']}`" for row in required)
    body.extend(["", "## Só se a pessoa pedir os shaders", ""])
    body.extend(f"- [{row['name']}]({row['page']}) `{row['filename']}`" for row in shaders)
    only = meta["server_only"]
    body.extend(["", f"Ficam só no servidor e não entram nesta lista: {only}.", ""])
    HUMAN.write_text("\n".join(body), encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        fail("uso: python3 scripts/sync_requirements.py /caminho/da/pasta/mods/do/servidor")
    mods_dir = Path(sys.argv[1])
    if not mods_dir.is_dir():
        fail(f"pasta não encontrada: {mods_dir}")
    meta, rows = load(REQUIREMENTS)
    server_only = set(meta["server_only"].split())
    by_id = {row["id"]: row for row in rows}
    seen: set[str] = set()
    pending: list[tuple[dict[str, str], str, Path]] = []

    for path in sorted(mods_dir.glob("*.jar")):
        mod_id, name = read_mod(path)
        if mod_id in server_only:
            continue
        file_sha1 = sha1_file(path)
        seen.add(mod_id)
        row = by_id.get(mod_id)
        if row is None:
            pending.append(({"id": mod_id, "name": name}, file_sha1, path))
            continue
        if row["origin"] != "server":
            fail(f"{mod_id} está no servidor e na ficha como mod só de cliente")
        if file_sha1 == row["sha1"] or (row["server_sha1"] != "-" and file_sha1 == row["server_sha1"]):
            row["name"] = name
            continue
        pending.append((row, file_sha1, path))

    looked = modrinth_by_hash([file_sha1 for _, file_sha1, _ in pending])
    for row, file_sha1, path in pending:
        version = looked.get(file_sha1)
        if version is None:
            fail(
                f"{path.name} mudou no servidor e esse arquivo não está no Modrinth. "
                "Atualize a URL na ficha à mão antes de commitar."
            )
        if "id" in row and row.get("side"):
            apply_version(row, version, file_sha1)
            row["name"] = read_mod(path)[1]
        else:
            created = {
                "side": "required",
                "id": row["id"],
                "name": row["name"],
                "filename": "",
                "sha1": "",
                "url": "",
                "dest": "mods",
                "patch": "-",
                "origin": "server",
                "server_sha1": "-",
                "page": "",
            }
            apply_version(created, version, file_sha1)
            rows.append(created)
            by_id[created["id"]] = created

    kept = []
    for row in rows:
        if row["origin"] == "server" and row["id"] not in seen:
            continue
        kept.append(row)
    write_requirements(meta, kept)
    print(f"ficha atualizada: {len(kept)} arquivos de cliente")


if __name__ == "__main__":
    main()
