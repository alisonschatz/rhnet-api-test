// Configuração do Allure Report 3 (lida automaticamente pelo ./mvnw allure:report).
// O histórico de tendências é mantido separado por ambiente, para que execuções de
// hml e prd não se misturem nos gráficos. O ambiente vem da variável ALLURE_AMBIENTE,
// definida pelos scripts rodar e pelo pipeline.
import { fileURLToPath } from "node:url";

const ambiente = process.env.ALLURE_AMBIENTE || "hml";

export default {
  historyPath: fileURLToPath(new URL(`./.allure/historico-${ambiente}.jsonl`, import.meta.url)),
  appendHistory: true,
};
