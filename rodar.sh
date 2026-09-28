#!/usr/bin/env bash
# ------------------------------------------------------------
#  Roda os testes, gera o relatório Allure e o abre.
#
#    ./rodar.sh              -> tudo em hml
#    ./rodar.sh prd          -> tudo em prd
#    ./rodar.sh hml smoke    -> só os testes @smoke em hml
#
#  O terminal mostra apenas o resumo. A saída completa do Maven
#  fica em target/execucao.log.
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

mkdir -p target
rm -f target/resumo-execucao.json target/resumo-console.txt

echo
echo "Testes em $AMBIENTE $TAGS"
echo "Executando... a primeira execução pode levar alguns minutos."

bash ./mvnw -B --no-transfer-progress test -Dkarate.env="$AMBIENTE" -Drodar=true \
  -Dmaven.test.failure.ignore=true ${TAGS:+-Dtags=$TAGS} > target/execucao.log 2>&1

if [[ ! -f target/resumo-console.txt ]]; then
  echo
  echo "=== A EXECUÇÃO FALHOU ANTES DOS TESTES ==="
  echo "Últimas linhas do log (completo em target/execucao.log):"
  echo
  tail -n 40 target/execucao.log
  exit 1
fi

echo
cat target/resumo-console.txt
FALHARAM=$(grep -o '"falharam": *[0-9]*' target/resumo-execucao.json | grep -o '[0-9]*$')

echo
echo "Gerando relatório Allure..."
ALLURE_AMBIENTE="$AMBIENTE" bash ./mvnw -B --no-transfer-progress allure:report > target/allure.log 2>&1

ALLURE="target/allure-report/index.html"
DETALHE="target/karate-reports/karate-summary.html"
abrir() {
  if command -v open > /dev/null; then open "$1" 2> /dev/null
  elif command -v xdg-open > /dev/null; then xdg-open "$1" > /dev/null 2>&1
  fi
}

echo
if [[ -f "$ALLURE" ]]; then
  echo "Relatório Allure:  $ALLURE"
else
  echo "Relatório Allure não gerado: veja target/allure.log"
fi
echo "Detalhe técnico:   $DETALHE"
echo "Log completo:      target/execucao.log"
if [[ -f "$ALLURE" ]]; then abrir "$ALLURE"; else abrir "$DETALHE"; fi

[[ "$FALHARAM" == "0" ]]
