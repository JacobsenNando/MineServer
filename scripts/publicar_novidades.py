#!/usr/bin/env python3
"""Publica uma nota com o bot do MineServer e atualiza o link no jogo."""

import argparse
import json
import re
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from uuid import uuid4


def discord(token, endpoint, payload=None, imagens=()):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    content_type = "application/json"
    if imagens:
        boundary = uuid4().hex
        content_type = f"multipart/form-data; boundary={boundary}"
        parts = [
            f'--{boundary}\r\nContent-Disposition: form-data; name="payload_json"\r\n'
            'Content-Type: application/json\r\n\r\n'.encode("ascii") + body + b"\r\n"
        ]
        for i, (nome, dados) in enumerate(imagens):
            header = (
                f'--{boundary}\r\nContent-Disposition: form-data; name="files[{i}]"; filename="{nome}"\r\n'
                'Content-Type: image/png\r\n\r\n'
            )
            parts.append(header.encode("ascii") + dados + b"\r\n")
        body = b"".join(parts) + f"--{boundary}--\r\n".encode("ascii")
    request = Request(
        "https://discord.com/api/v10" + endpoint,
        data=body,
        headers={
            "Authorization": "Bot " + token,
            "Content-Type": content_type,
            "User-Agent": "MineServerNovidades",
        },
    )
    with urlopen(request, timeout=10) as response:
        return json.load(response)


def id_discord(value, descricao):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]+", value):
        raise ValueError(f"{descricao} inválido.")
    return value


def salvar_nota(config, titulo, link, importante):
    destino = config / "mineserver-novidades.properties"
    arquivo_temporario = None
    titulo_properties = titulo.replace("\\", "\\\\")
    try:
        with NamedTemporaryFile(mode="w", encoding="utf-8", dir=config, delete=False) as arquivo:
            arquivo_temporario = Path(arquivo.name)
            arquivo.write(f"link={link}\ntitulo={titulo_properties}\n")
            arquivo.write(f"importante={str(importante).lower()}\n")
        arquivo_temporario.replace(destino)
    finally:
        if arquivo_temporario is not None:
            arquivo_temporario.unlink(missing_ok=True)


def publicar(config, titulo, mensagem, importante, cargo=None, imagens=(), canal_publicacao="chat"):
    ponte = json.loads((config / "discord-mc-chat.json").read_text(encoding="utf-8"))["generic"]
    canal_ponte = id_discord(ponte.get("channelId"), "Canal da ponte do Minecraft")
    token = ponte.get("botToken", "").strip()
    arquivo_token = config / "discord-bot.token"
    if not token and arquivo_token.is_file():
        token = arquivo_token.read_text(encoding="utf-8").strip()
    if not token:
        raise ValueError("O bot está sem token configurado.")

    servidor = id_discord(discord(token, f"/channels/{canal_ponte}").get("guild_id"), "Servidor do Discord")
    canais = discord(token, f"/guilds/{servidor}/channels")
    destinos = [c["id"] for c in canais
                if c["type"] in (0, 5) and c["name"].casefold() == canal_publicacao.lstrip("#").casefold()]
    if len(destinos) != 1:
        raise ValueError("O canal de publicação precisa corresponder a um único canal de texto.")
    canal = id_discord(destinos[0], "Canal de publicação")
    if canal == canal_ponte:
        raise ValueError("Escolha um canal separado da ponte do Minecraft.")

    mencoes = {"parse": []}
    prefixo = ""
    if cargo:
        cargos = discord(token, f"/guilds/{servidor}/roles")
        ids = [role["id"] for role in cargos if role["name"].casefold() == cargo.lstrip("@").casefold()]
        if len(ids) != 1:
            raise ValueError("O cargo informado não corresponde a um cargo único no Discord.")
        cargo_id = id_discord(ids[0], "ID do cargo")
        mencoes["roles"] = [cargo_id]
        prefixo = f"<@&{cargo_id}>\n"

    conteudo = f"{prefixo}**{titulo}**\n\n{mensagem}"
    if len(conteudo) > 2000:
        raise ValueError("O título, a mensagem e a menção passam de 2.000 caracteres.")
    payload = {"content": conteudo, "allowed_mentions": mencoes}
    if imagens:
        payload["attachments"] = [{"id": i, "filename": nome} for i, (nome, _) in enumerate(imagens)]
    postagem = discord(token, f"/channels/{canal}/messages", payload, imagens)
    mensagem_id = id_discord(postagem.get("id"), "Mensagem publicada")
    link = f"https://discord.com/channels/{servidor}/{canal}/{mensagem_id}"
    print(link)
    salvar_nota(config, titulo, link, importante)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--servidor", required=True, type=Path, help="pasta do servidor Minecraft")
    parser.add_argument("--titulo", required=True, help="título da nota")
    parser.add_argument("--mensagem", required=True, type=Path, help="arquivo UTF-8 com o texto da nota")
    parser.add_argument("--importante", action="store_true", help="avisa os jogadores no próximo login")
    parser.add_argument("--canal", default="chat", help="canal das notas (padrão: #chat)")
    parser.add_argument("--cargo", help="nome de um único cargo a mencionar, por exemplo @mineplayer")
    parser.add_argument("--imagem", action="append", type=Path, default=[], help="card PNG para anexar; pode ser repetido")
    args = parser.parse_args()

    try:
        titulo = args.titulo.strip()
        mensagem = args.mensagem.read_text(encoding="utf-8").strip()
        if not titulo or len(titulo.splitlines()) != 1 or not mensagem:
            raise ValueError("Informe um título de uma linha e uma mensagem com texto.")
        if len(f"**{titulo}**\n\n{mensagem}") > 2000:
            raise ValueError("O título e a mensagem juntos passam de 2.000 caracteres.")
        imagens = []
        nomes = set()
        if len(args.imagem) > 10:
            raise ValueError("O Discord aceita até 10 anexos por mensagem.")
        for caminho in args.imagem:
            nome = caminho.name
            if not re.fullmatch(r"[a-zA-Z0-9_.-]+\.png", nome) or nome in nomes:
                raise ValueError("Cada card precisa de um nome PNG válido e único.")
            dados = caminho.read_bytes()
            if not dados.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(f"{nome} não é um PNG.")
            imagens.append((nome, dados))
            nomes.add(nome)
        publicar(args.servidor / "config", titulo, mensagem, args.importante, args.cargo, imagens, args.canal)
    except HTTPError as erro:
        parser.exit(1, f"O Discord retornou HTTP {erro.code}.\n")
    except (URLError, TimeoutError):
        parser.exit(1, "A resposta do Discord falhou. Confira o canal antes de tentar de novo.\n")
    except (OSError, KeyError, ValueError) as erro:
        parser.exit(1, f"Não foi possível concluir a publicação: {erro}\n")


if __name__ == "__main__":
    main()
