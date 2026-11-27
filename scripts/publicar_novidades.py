#!/usr/bin/env python3
"""Publica uma nota com o bot do MineServer e atualiza o link no jogo."""

import argparse
import json
import re
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def discord(token, endpoint, payload=None):
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    request = Request(
        "https://discord.com/api/v10" + endpoint,
        data=body,
        headers={
            "Authorization": "Bot " + token,
            "Content-Type": "application/json",
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


def publicar(config, titulo, mensagem, importante):
    ponte = json.loads((config / "discord-mc-chat.json").read_text(encoding="utf-8"))["generic"]
    canal = id_discord(ponte.get("channelId"), "Canal principal do bot")
    token = ponte.get("botToken", "").strip()
    arquivo_token = config / "discord-bot.token"
    if not token and arquivo_token.is_file():
        token = arquivo_token.read_text(encoding="utf-8").strip()
    if not token:
        raise ValueError("O bot está sem token configurado.")

    servidor = id_discord(discord(token, f"/channels/{canal}").get("guild_id"), "Servidor do Discord")
    postagem = discord(token, f"/channels/{canal}/messages", {
        "content": f"**{titulo}**\n\n{mensagem}",
        "allowed_mentions": {"parse": []},
    })
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
    args = parser.parse_args()

    try:
        titulo = args.titulo.strip()
        mensagem = args.mensagem.read_text(encoding="utf-8").strip()
        if not titulo or len(titulo.splitlines()) != 1 or not mensagem:
            raise ValueError("Informe um título de uma linha e uma mensagem com texto.")
        if len(f"**{titulo}**\n\n{mensagem}") > 2000:
            raise ValueError("O título e a mensagem juntos passam de 2.000 caracteres.")
        publicar(args.servidor / "config", titulo, mensagem, args.importante)
    except HTTPError as erro:
        parser.exit(1, f"O Discord retornou HTTP {erro.code}.\n")
    except (URLError, TimeoutError):
        parser.exit(1, "A resposta do Discord falhou. Confira o canal antes de tentar de novo.\n")
    except (OSError, KeyError, ValueError) as erro:
        parser.exit(1, f"Não foi possível concluir a publicação: {erro}\n")


if __name__ == "__main__":
    main()
