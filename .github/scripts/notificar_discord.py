#!/usr/bin/env python3
"""
Envia ao Discord o aviso de uma execução dos testes, com o resultado e o link do relatório.

Uso: notificar_discord.py <ambiente> <caminho-do-status.json>

Variáveis de ambiente:
  DISCORD_WEBHOOK_URL   URL do webhook do canal (secret). Sem ela, o aviso não é enviado.
  RELATORIO_URL         link do relatório publicado (vazio se a publicação não ocorreu)
  EXECUCAO_URL          link da execução no GitHub Actions

Uma falha no envio só gera um aviso no log: nunca altera o resultado do pipeline.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# Mesmas cores de status do Allure Report
VERDE, VERMELHO, CINZA = 0x3BC95D, 0xF43F3B, 0xA5B7D1
NOMES = {"hml": "Homologação", "prd": "Produção"}


def duracao(ms):
    segundos = (ms or 0) / 1000
    if segundos < 60:
        return f"{segundos:.1f} s".replace(".", ",")
    minutos, resto = divmod(int(round(segundos)), 60)
    return f"{minutos} min {resto} s"


def montar(ambiente, status, relatorio_url, execucao_url):
    amb = ambiente.upper()
    titulo_amb = f"{NOMES.get(ambiente, amb)} ({amb})"
    links = []
    if relatorio_url:
        links.append(f"[Abrir relatório]({relatorio_url})")
    if execucao_url:
        links.append(f"[Execução no GitHub Actions]({execucao_url})")

    if status is None:
        return {
            "title": f"⚠️ Testes não executados · {titulo_amb}",
            "color": CINZA,
            "description": "Não foi possível executar os testes (credenciais, acesso à API ou configuração).\n"
                           + " · ".join(links),
        }

    passou = status.get("resultado") == "passou"
    total, falharam = status.get("total", 0), status.get("falharam", 0)
    campos = [
        {"name": "Cenários", "value": str(total), "inline": True},
        {"name": "Passaram", "value": str(status.get("passaram", 0)), "inline": True},
        {"name": "Falharam", "value": str(falharam), "inline": True},
        {"name": "Executado em", "value": status.get("executadoEm", "—"), "inline": True},
        {"name": "Duração", "value": duracao(status.get("duracaoMs")), "inline": True},
    ]
    if status.get("versao"):
        campos.append({"name": "Versão implantada", "value": status["versao"], "inline": True})

    descricao = ("Todos os cenários passaram." if passou
                 else f"**{falharam} de {total} cenário(s) falharam.**")
    if not relatorio_url:
        descricao += "\nO relatório não pôde ser publicado nesta execução."
    return {
        "title": f"{'✅' if passou else '❌'} Testes de API · {titulo_amb}",
        "url": relatorio_url or execucao_url or None,
        "color": VERDE if passou else VERMELHO,
        "description": descricao + ("\n" + " · ".join(links) if links else ""),
        "fields": campos,
    }


def main():
    webhook = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if not webhook:
        print("DISCORD_WEBHOOK_URL não configurado: aviso não enviado.")
        return

    ambiente, caminho_status = sys.argv[1], Path(sys.argv[2])
    status = json.loads(caminho_status.read_text(encoding="utf-8")) if caminho_status.is_file() else None

    embed = montar(ambiente, status,
                   os.environ.get("RELATORIO_URL", "").strip(),
                   os.environ.get("EXECUCAO_URL", "").strip())
    embed = {k: v for k, v in embed.items() if v is not None}
    embed["footer"] = {"text": "RH NET Social · Testes de API"}
    embed["timestamp"] = datetime.now(timezone.utc).isoformat()

    corpo = json.dumps({"embeds": [embed], "allowed_mentions": {"parse": []}}).encode("utf-8")
    requisicao = urllib.request.Request(webhook, data=corpo, method="POST", headers={
        "Content-Type": "application/json",
        "User-Agent": "rhnet-api-tests (GitHub Actions)",
    })
    try:
        with urllib.request.urlopen(requisicao, timeout=15) as resposta:
            print(f"Aviso enviado ao Discord (HTTP {resposta.status}).")
    except urllib.error.HTTPError as e:
        print(f"::warning title=Aviso no Discord não enviado::HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
    except Exception as e:  # rede, DNS, timeout
        print(f"::warning title=Aviso no Discord não enviado::{e}")


if __name__ == "__main__":
    main()
