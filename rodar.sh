#!/usr/bin/env bash
# ------------------------------------------------------------
#  Roda os testes e abre o relatório.
#
#    ./rodar.sh              -> tudo em hml
#    ./rodar.sh prd          -> tudo em prd
#    ./rodar.sh hml smoke    -> só os testes @smoke em hml
# ------------------------------------------------------------
cd "$(dirname "$0")"

AMBIENTE="${1:-hml}"
TAGS="${2:-}"

if [[ "$AMBIENTE" != "hml" && "$AMBIENTE" != "prd" ]]; then
  echo "Ambiente inválido: $AMBIENTE. Use hml ou prd."
  exit 1
fi

if [[ ! -f ".env.$AMBIENTE" ]]; then
  echo "Arquivo .env.$AMBIENTE não encontrado."
  echo "Copie o .env.example para .env.$AMBIENTE e preencha as credenciais."
  exit 1
fi

[[ -n "$TAGS" && "$TAGS" != @* ]] && TAGS="@$TAGS"

echo
echo "=== Rodando testes em $AMBIENTE $TAGS ==="
echo

bash ./mvnw -B --no-transfer-progress test -Dkarate.env="$AMBIENTE" ${TAGS:+-Dtags=$TAGS}
RESULTADO=$?

PAINEL="target/cucumber-html-reports/overview-features.html"
DETALHE="target/karate-reports/karate-summary.html"
abrir() {
  if command -v open > /dev/null; then open "$1"
  elif command -v xdg-open > /dev/null; then xdg-open "$1" > /dev/null 2>&1
  fi
}

echo
if [[ ! -f "$DETALHE" ]]; then
  echo "=== A EXECUÇÃO FALHOU ANTES DOS TESTES - veja as mensagens acima ==="
  exit $RESULTADO
fi
if [[ $RESULTADO -eq 0 ]]; then
  echo "=== TODOS OS TESTES PASSARAM ==="
else
  echo "=== HÁ TESTES FALHANDO ==="
fi
echo
echo "Painel de resultados:  $PAINEL"
echo "Detalhe técnico:       $DETALHE"
if [[ -f "$PAINEL" ]]; then abrir "$PAINEL"; else abrir "$DETALHE"; fi
exit $RESULTADO
