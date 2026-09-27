#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Monta o site com o último relatório Allure de cada ambiente e o guarda na branch "relatorios".
#
#   Uso: publicar-relatorio.sh <ambiente> <pasta-da-execução> <pasta-de-saída-do-site>
#
# A pasta da execução contém: index.html (relatório), historico-<ambiente>.jsonl e status.json.
# A pasta de saída recebe o site pronto, que o pipeline publica no GitHub Pages.
#
# A branch "relatorios" é o armazenamento entre execuções (não é servida pelo Pages) e é
# recriada a cada publicação com um único commit (push forçado):
#   index.html, assets/             página inicial (template em .github/pages/)
#   <ambiente>/index.html           último relatório de cada ambiente (substitui o anterior)
#   .historico/                     histórico de tendências e status (fica fora do site publicado)
#
# Assim, só o último relatório de cada ambiente fica acessível; das execuções anteriores
# resta apenas o resumo usado nos gráficos de tendência.
# ------------------------------------------------------------------------------
set -euo pipefail

AMBIENTE="$1"
EXECUCAO="$(cd "$2" && pwd)"
mkdir -p "$3"
SITE="$(cd "$3" && pwd)"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
BRANCH="relatorios"

# Conteúdo atual (preserva o outro ambiente e os históricos)
if git fetch --depth 1 origin "$BRANCH" 2> /dev/null; then
  git archive FETCH_HEAD | tar -x -C "$SITE"
fi

mkdir -p "$SITE/$AMBIENTE" "$SITE/.historico"
cp "$EXECUCAO/index.html" "$SITE/$AMBIENTE/index.html"
cp "$EXECUCAO/status.json" "$SITE/.historico/status-$AMBIENTE.json"
if [[ -f "$EXECUCAO/historico-$AMBIENTE.jsonl" ]]; then
  cp "$EXECUCAO/historico-$AMBIENTE.jsonl" "$SITE/.historico/historico-$AMBIENTE.jsonl"
fi

# Página inicial
python3 "$RAIZ/.github/scripts/gerar_pagina_inicial.py" "$SITE" "$RAIZ/.github/pages"

# Recria a branch com um único commit: nenhuma versão anterior dos relatórios é mantida.
# O repositório Git temporário fica fora da pasta do site, que é publicada em seguida.
GIT_TMP="$(mktemp -d)"
export GIT_DIR="$GIT_TMP/.git" GIT_WORK_TREE="$SITE"
git init -q
git checkout -q --orphan "$BRANCH"
git add -A
git -c user.name="github-actions[bot]" -c user.email="github-actions[bot]@users.noreply.github.com" \
  commit -q -m "Relatórios: publicação de $AMBIENTE"
DESTINO="${DESTINO_PUSH:-https://x-access-token:${GITHUB_TOKEN:-}@github.com/${GITHUB_REPOSITORY:-}.git}"
git push -q -f "$DESTINO" "$BRANCH"
unset GIT_DIR GIT_WORK_TREE
rm -rf "$GIT_TMP"
echo "Site montado em $SITE e salvo na branch $BRANCH (relatório de $AMBIENTE)."
