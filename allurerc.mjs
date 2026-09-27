// Configuração do Allure Report 3 (lida automaticamente pelo ./mvnw allure:report).
//
// O ambiente vem da variável ALLURE_AMBIENTE, definida pelos scripts rodar e pelo pipeline.
// - Histórico de tendências separado por ambiente, para que hml e prd não se misturem.
// - Interface em português por padrão (quem trocar o idioma no relatório mantém a própria escolha).
// - No GitHub Actions, o relatório exibe o link da execução que o gerou.
import { fileURLToPath } from "node:url";

const ambiente = process.env.ALLURE_AMBIENTE || "hml";

const { GITHUB_SERVER_URL, GITHUB_REPOSITORY, GITHUB_RUN_ID } = process.env;
const execucaoGithub = GITHUB_RUN_ID
  ? {
      type: "github",
      url: `${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}`,
      name: "Execução no GitHub Actions",
    }
  : undefined;

export default {
  historyPath: fileURLToPath(new URL(`./.allure/historico-${ambiente}.jsonl`, import.meta.url)),
  appendHistory: true,
  plugins: {
    awesome: {
      options: {
        reportName: `RH NET Social · Testes de API (${ambiente.toUpperCase()})`,
        reportLanguage: "pt",
        ...(execucaoGithub && { ci: execucaoGithub }),
      },
    },
  },
};
