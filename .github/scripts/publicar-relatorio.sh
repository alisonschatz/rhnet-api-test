#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Publica o último relatório Allure de um ambiente no GitHub Pages (branch gh-pages).
#
#   Uso: publicar-relatorio.sh <ambiente> <pasta-com-os-arquivos-da-execução>
#
# A pasta da execução contém: index.html (relatório), historico-<ambiente>.jsonl e status.txt.
#
# A branch gh-pages é recriada a cada publicação com um único commit (push forçado):
#   index.html                      página inicial com hml e prd
#   <ambiente>/index.html           último relatório de cada ambiente (substitui o anterior)
#   .historico/                     histórico de tendências e status (NÃO é servido pelo Pages)
#
# Assim, só o último relatório de cada ambiente fica acessível; das execuções anteriores
# resta apenas o resumo usado nos gráficos de tendência.
# ------------------------------------------------------------------------------
set -euo pipefail

AMBIENTE="$1"
EXECUCAO="$2"
SITE="$(mktemp -d)"

# Conteúdo atual publicado (preserva o outro ambiente e os históricos)
if git fetch --depth 1 origin gh-pages 2> /dev/null; then
  git archive FETCH_HEAD | tar -x -C "$SITE"
fi

mkdir -p "$SITE/$AMBIENTE" "$SITE/.historico"
cp "$EXECUCAO/index.html" "$SITE/$AMBIENTE/index.html"
cp "$EXECUCAO/status.txt" "$SITE/.historico/status-$AMBIENTE.txt"
if [[ -f "$EXECUCAO/historico-$AMBIENTE.jsonl" ]]; then
  cp "$EXECUCAO/historico-$AMBIENTE.jsonl" "$SITE/.historico/historico-$AMBIENTE.jsonl"
fi

# Página inicial
cartao() {
  local amb="$1" titulo="$2"
  if [[ ! -f "$SITE/.historico/status-$amb.txt" ]]; then
    echo "<div class=\"cartao vazio\"><h2>$titulo</h2><p>Nenhuma execução publicada.</p></div>"
    return
  fi
  local data resultado classe texto
  IFS='|' read -r data resultado < "$SITE/.historico/status-$amb.txt"
  if [[ "$resultado" == "success" ]]; then classe="ok"; texto="Todos os testes passaram"
  else classe="falha"; texto="Há testes falhando"; fi
  echo "<a class=\"cartao $classe\" href=\"$amb/\"><h2>$titulo</h2><p class=\"resultado\">$texto</p><p>Atualizado em $data</p><span>Abrir relatório →</span></a>"
}

cat > "$SITE/index.html" <<HTML
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RH NET Social - Testes de API</title>
<style>
  body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; margin: 0; background: #f5f6f8; color: #1f2933; }
  main { max-width: 760px; margin: 0 auto; padding: 48px 24px; }
  h1 { font-size: 1.6rem; margin: 0 0 4px; }
  .sub { color: #52606d; margin: 0 0 32px; }
  .grade { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
  .cartao { display: block; background: #fff; border-radius: 10px; padding: 20px 24px; text-decoration: none; color: inherit;
            border-left: 6px solid #9aa5b1; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
  .cartao h2 { margin: 0 0 8px; font-size: 1.2rem; }
  .cartao p { margin: 4px 0; color: #52606d; }
  .cartao .resultado { font-weight: 600; color: #1f2933; }
  .cartao span { display: inline-block; margin-top: 12px; font-weight: 600; color: #2563eb; }
  .ok { border-left-color: #16a34a; }
  .falha { border-left-color: #dc2626; }
  footer { margin-top: 32px; font-size: .85rem; color: #7b8794; }
</style>
</head>
<body>
<main>
  <h1>RH NET Social - Testes de API</h1>
  <p class="sub">Último relatório de cada ambiente, com o histórico de tendências das execuções anteriores.</p>
  <div class="grade">
    $(cartao hml "Homologação (HML)")
    $(cartao prd "Produção (PRD)")
  </div>
  <footer>Relatórios gerados automaticamente pelo pipeline a cada execução.</footer>
</main>
</body>
</html>
HTML

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
