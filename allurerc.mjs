// Configuração do Allure Report 3 (lida automaticamente pelo ./mvnw allure:report).
//
// O ambiente vem da variável ALLURE_AMBIENTE, definida pelos scripts rodar e pelo pipeline.
// - Histórico de tendências separado por ambiente, para que hml e prd não se misturem.
// - Interface em português por padrão (quem trocar o idioma no relatório mantém a própria escolha).
// - No GitHub Actions, o relatório exibe o link da execução que o gerou.
// - Categorias próprias: agrupam as falhas pela natureza do problema. Cenários com a tag
//   @bug-<chamado> (bug já reportado) ficam na categoria "Falhas conhecidas".
//
// O nome do relatório não é definido aqui: o plugin allure-maven o fixa como "Allure".
// Ele é ajustado depois da geração por scripts/NomeRelatorioAllure.java.
import { fileURLToPath } from "node:url";

const ambiente = process.env.ALLURE_AMBIENTE || "hml";
const arquivo = (nome) => fileURLToPath(new URL(`./${nome}`, import.meta.url));

// ------------------------------------------------------------------ CI
const { GITHUB_SERVER_URL, GITHUB_REPOSITORY, GITHUB_RUN_ID } = process.env;
const execucaoGithub = GITHUB_RUN_ID
  ? {
      type: "github",
      url: `${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}`,
      name: "Execução no GitHub Actions",
    }
  : undefined;

// ------------------------------------------------------------ categorias
// Avaliadas em ordem: a primeira que reconhecer a falha é a usada.
const categorias = [
  // Tag @bug-<chamado> no cenário, repassada ao Allure por rhnet.support.relatorio.Bugs
  { name: "Falhas conhecidas (bug já reportado)", matchers: { statuses: ["failed", "broken"], labels: { tag: /^bug-/ } } },
  {
    name: "Configuração do ambiente",
    matchers: { message: /não está pronto para os testes|Credenciais de .* ausentes|Falha ao gerar o token|dados-teste\.json|ambientes\.json/ },
  },
  { name: "Contrato violado (resposta difere da spec)", matchers: { message: /CONTRATO VIOLADO/ } },
  { name: "Spec inválida ou ausente", matchers: { message: /SPEC INVÁLIDA|SPEC NÃO ENCONTRADA/ } },
  { name: "Erro interno da API (5xx)", matchers: { message: /actual: 5\d\d|status code was: 5\d\d/ } },
  {
    name: "Autenticação e permissão (401/403)",
    matchers: { message: /expected(?: status)?: 40[13]\b|responseStatus == 400 \|\| responseStatus == 403/ },
  },
  { name: "Validação de dados (400)", matchers: { message: /expected(?: status)?: 400\b/ } },
  { name: "Pré-condição do teste não atendida", matchers: { message: /Pré-condição/ } },
  { name: "Conteúdo da resposta divergente", matchers: { message: /match failed/ } },
  { name: "Outras falhas da API", matchers: { statuses: ["failed"] } },
  { name: "Outros erros de execução", matchers: { statuses: ["broken"] } },
];

export default {
  historyPath: arquivo(`.allure/historico-${ambiente}.jsonl`),
  appendHistory: true,
  categories: categorias,
  plugins: {
    awesome: {
      options: {
        reportLanguage: "pt",
        ...(execucaoGithub && { ci: execucaoGithub }),
      },
    },
  },
};
