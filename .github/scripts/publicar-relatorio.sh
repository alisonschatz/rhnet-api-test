#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Publica o último relatório Allure de um ambiente no GitHub Pages (branch gh-pages).
#
#   Uso: publicar-relatorio.sh <ambiente> <pasta-com-os-arquivos-da-execução>
#
# A pasta da execução contém: index.html (relatório), historico-<ambiente>.jsonl e status.json.
#
# A branch gh-pages é recriada a cada publicação com um único commit (push forçado):
#   index.html, assets/             página inicial (template em .github/pages/)
#   <ambiente>/index.html           último relatório de cada ambiente (substitui o anterior)
#   .historico/                     histórico de tendências e status (NÃO é servido pelo Pages)
#
# Assim, só o último relatório de cada ambiente fica acessível; das execuções anteriores
# resta apenas o resumo usado nos gráficos de tendência.
# ------------------------------------------------------------------------------
set -euo pipefail

AMBIENTE="$1"
EXECUCAO="$(cd "$2" && pwd)"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
SITE="$(mktemp -d)"

# Conteúdo atual publicado (preserva o outro ambiente e os históricos)
if git fetch --depth 1 origin gh-pages 2> /dev/null; then
  git archive FETCH_HEAD | tar -x -C "$SITE"
fi

mkdir -p "$SITE/$AMBIENTE" "$SITE/.historico"
cp "$EXECUCAO/index.html" "$SITE/$AMBIENTE/index.html"
cp "$EXECUCAO/status.json" "$SITE/.historico/status-$AMBIENTE.json"
rm -f "$SITE/.historico/status-$AMBIENTE.txt"
if [[ -f "$EXECUCAO/historico-$AMBIENTE.jsonl" ]]; then
  cp "$EXECUCAO/historico-$AMBIENTE.jsonl" "$SITE/.historico/historico-$AMBIENTE.jsonl"
fi

# Página inicial
python3 "$RAIZ/.github/scripts/gerar_pagina_inicial.py" "$SITE" "$RAIZ/.github/pages"

# Recria a branch com um único commit: nenhuma versão anterior dos relatórios é mantida
cd "$SITE"
git init -q
git checkout -q --orphan gh-pages
git add -A
git -c user.name="github-actions[bot]" -c user.email="github-actions[bot]@users.noreply.github.com" \
  commit -q -m "Relatórios: publicação de $AMBIENTE"
DESTINO="${DESTINO_PUSH:-https://x-access-token:${GITHUB_TOKEN:-}@github.com/${GITHUB_REPOSITORY:-}.git}"
git push -q -f "$DESTINO" gh-pages
echo "Relatório de $AMBIENTE publicado."
