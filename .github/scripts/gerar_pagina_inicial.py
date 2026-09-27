#!/usr/bin/env python3
"""
Gera a página inicial do site publicado (index.html) a partir do template
.github/pages/index.html e dos dados da última execução de cada ambiente,
guardados em <site>/.historico/status-<ambiente>.json.

Uso: gerar_pagina_inicial.py <pasta-do-site> <pasta-do-template>
"""
import html
import re
import json
import shutil
import sys
from pathlib import Path

AMBIENTES = [("hml", "Homologação"), ("prd", "Produção")]


def duracao(ms):
    segundos = (ms or 0) / 1000
    if segundos < 60:
        return f"{segundos:.1f} s".replace(".", ",")
    minutos, resto = divmod(int(round(segundos)), 60)
    return f"{minutos} min {resto} s"


def ler_status(historico: Path, amb: str):
    arquivo_json = historico / f"status-{amb}.json"
    if arquivo_json.exists():
        return json.loads(arquivo_json.read_text(encoding="utf-8"))
    # Formato antigo ("data|resultado"), de publicações anteriores a esta versão
    arquivo_txt = historico / f"status-{amb}.txt"
    if arquivo_txt.exists():
        data, _, resultado = arquivo_txt.read_text(encoding="utf-8").strip().partition("|")
        return {"executadoEm": data, "resultado": "passou" if resultado == "success" else "falhou"}
    return None


def cartao_vazio(amb, titulo):
    return f"""
      <section class="cartao">
        <div class="cartao-topo">
          <div><h2>{titulo}</h2><div class="ambiente">{amb.upper()}</div></div>
          <span class="status vazio">Sem execução</span>
        </div>
        <p class="vazio-texto">Nenhum relatório publicado para este ambiente ainda.</p>
      </section>"""


def cartao(amb, titulo, s):
    e = lambda v: html.escape(str(v)) if v not in (None, "") else "—"
    passou = s.get("resultado") == "passou"
    total, passaram, falharam = s.get("total"), s.get("passaram"), s.get("falharam")

    metricas = barra = ""
    if total is not None:
        pct_ok = (passaram / total * 100) if total else 0
        pct_falha = (falharam / total * 100) if total else 0
        metricas = f"""
        <div class="metricas">
          <div class="metrica"><div class="valor">{total}</div><div class="rotulo">Cenários</div></div>
          <div class="metrica passou"><div class="valor">{passaram}</div><div class="rotulo">Passaram</div></div>
          <div class="metrica falhou"><div class="valor">{falharam}</div><div class="rotulo">Falharam</div></div>
        </div>
        <div class="barra" role="img" aria-label="{passaram} de {total} cenários passaram">
          <span class="passou" style="width:{pct_ok:.2f}%"></span><span class="falhou" style="width:{pct_falha:.2f}%"></span>
        </div>"""

    detalhes = [("Executado em", e(s.get("executadoEm")))]
    if "duracaoMs" in s:
        detalhes.append(("Duração", duracao(s["duracaoMs"])))
    if s.get("versao"):
        detalhes.append(("Versão implantada", e(s["versao"])))
    if s.get("spec"):
        # "Spec hml | rhnetsocial: 2026-09-25 (v1.5.0)" -> "rhnetsocial: 2026-09-25 (v1.5.0)"
        detalhes.append(("Spec", e(re.sub(r"^Spec\s+\w+\s*\|\s*", "", s["spec"]))))
    dl = "".join(f"<dt>{r}</dt><dd>{v}</dd>" for r, v in detalhes)

    execucao = ""
    if s.get("execucaoUrl"):
        execucao = f'<a class="link" href="{html.escape(s["execucaoUrl"])}" target="_blank" rel="noopener">Execução no GitHub Actions</a>'

    return f"""
      <section class="cartao">
        <div class="cartao-topo">
          <div><h2>{titulo}</h2><div class="ambiente">{amb.upper()}</div></div>
          <span class="status {'passou' if passou else 'falhou'}">{'Todos passaram' if passou else 'Com falhas'}</span>
        </div>{metricas}
        <dl class="detalhes">{dl}</dl>
        <div class="acoes">
          <a class="botao" href="{amb}/">Abrir relatório</a>
          {execucao}
        </div>
      </section>"""


def main():
    site, template = Path(sys.argv[1]), Path(sys.argv[2])
    historico = site / ".historico"
    cartoes = []
    for amb, titulo in AMBIENTES:
        status = ler_status(historico, amb)
        cartoes.append(cartao(amb, titulo, status) if status else cartao_vazio(amb, titulo))

    pagina = (template / "index.html").read_text(encoding="utf-8").replace("{{CARTOES}}", "".join(cartoes))
    (site / "index.html").write_text(pagina, encoding="utf-8")
    shutil.copytree(template / "assets", site / "assets", dirs_exist_ok=True)


if __name__ == "__main__":
    main()
