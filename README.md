# RH NET Social - Testes de API

Testes automatizados dos endpoints da API **RH NET Social**, em repositório independente do
código da aplicação. Rodam em **homologação (hml)** e em **produção (prd)**, a cada deploy e sob demanda.

**Stack:** Karate 2 · Java 21 · JUnit 6 · Allure Report 3 · Maven (via Maven Wrapper) · GitHub Actions

---

## Como funciona

1. O dev faz deploy e o pipeline dele dispara este repositório, informando o ambiente.
2. O Karate gera o token de acesso **uma vez** na API de autenticação e roda as features em paralelo.
3. Cada resposta testada é conferida contra a **spec oficial do ambiente** (`spec/<ambiente>/rhnetsocial.json`),
   baixada e validada pelo QA.
4. Ao final, são gerados o relatório Allure, o relatório técnico do Karate e um resumo da execução.

### Escopo

O alvo dos testes são os endpoints da **RH NET Social**. A **API de autenticação** é usada apenas para
gerar o token: se ele não for gerado, a execução é interrompida com a causa, antes dos testes.

Todos os testes rodam nos dois ambientes, inclusive os que criam, alteram e removem dados,
sempre com **usuários e contas exclusivos para teste**. Todo dado criado é removido ao final do cenário.

---

## Estrutura

```
├── ambientes.json                      # URLs de cada ambiente (hml, prd)
├── .env.example                        # modelo do .env.hml / .env.prd (credenciais)
├── spec/
│   ├── hml/  rhnetsocial.json, INFO.md # spec oficial e histórico de cada ambiente
│   └── prd/  rhnetsocial.json, INFO.md
├── allurerc.mjs                        # configuração do Allure Report (histórico por ambiente)
├── rodar.cmd / rodar.sh                # atalho para rodar localmente
├── pom.xml                             # dependências do projeto
├── mvnw / mvnw.cmd / .mvn/             # Maven Wrapper (não precisa instalar Maven)
├── .github/
│   ├── workflows/api-tests.yml         # pipeline (hml e prd)
│   └── scripts/publicar-relatorio.sh   # publicação do relatório no GitHub Pages
└── src/test/
    ├── resources/
    │   ├── contrato-ignorar.txt        # exceções de contrato aceitas (com motivo)
    │   ├── allure.properties           # onde o Allure grava os resultados
    │   └── logback-test.xml            # logs do console
    └── java/
        ├── karate-config.js            # configuração global: ambiente, token, máscara, helpers
        └── rhnet/
            ├── RhnetTest.java          # ponto de execução (paralelo, tags, Allure)
            │
            ├── features/               # OS TESTES, uma pasta por área da API
            │   └── consultas/
            │       └── bancos.feature
            │
            ├── modelos/                # modelos para novas features (não executam)
            │
            └── support/                # infraestrutura, organizada por responsabilidade
                ├── auth/               #   geração do token da execução
                │   ├── obter-token.feature
                │   └── Autenticacao.java       Basic Auth e leitura do JWT
                ├── contrato/           #   validação de respostas contra a spec
                │   ├── ValidadorContrato.java  carrega a spec e valida
                │   ├── MensagensContrato.java  monta as mensagens do relatório
                │   └── LocalizadorJson.java    localiza linha e caminho na spec
                ├── dados/              #   massa de dados sintética
                │   └── GeradorDados.java       CPF válido, nomes, datas
                └── relatorio/          #   resumo da execução
                    └── ResumoExecucao.java     tabela de resultados (GitHub Actions)
```

Onde colocar algo novo:
- **Um teste:** `features/<área>/<recurso>.feature`.
- **Infraestrutura reutilizável:** a pasta de `support/` da responsabilidade correspondente,
  ou uma pasta nova se for uma responsabilidade nova (ex.: `support/arquivos/` para uploads).

### Disponível em todas as features

Definido em `karate-config.js`, sem precisar declarar nada:

| Nome | Conteúdo |
|---|---|
| `baseUrl`, `authUrl` | URLs da RH NET Social e da API de auth do ambiente |
| `ambiente` | `hml` ou `prd` |
| `token` | JWT do usuário de teste |
| `sessao` | Dados do JWT, ex.: `sessao.sistemaId`, `sessao.usuario.dados.empresasVinculadas` |
| `validarContrato()` | Valida a última resposta contra a spec da RH NET Social do ambiente |
| `registrar(texto)` | Registra uma verificação em português nos relatórios (Allure e Karate) |

---

## Rodando localmente

Pré-requisito (uma vez só): **Java 21 ou superior** e acesso à rede das APIs (VPN, se for o caso).

- Windows: `winget install EclipseAdoptium.Temurin.21.JDK`
- O **Maven não precisa ser instalado**: o Maven Wrapper (`mvnw`) baixa a versão fixada no projeto.
- O **Allure não precisa ser instalado**: o plugin baixa o Allure e um Node.js próprio para a pasta
  `.allure` na primeira geração do relatório.

**1. Credenciais:** copie o `.env.example` para `.env.hml` (e `.env.prd`, se for usar) e preencha os tokens.

**2. URLs:** confira o `ambientes.json`.

**3. Rode:**

| Windows (PowerShell) | Linux / Mac | O que faz |
|---|---|---|
| `.\rodar` | `./rodar.sh` | Tudo em hml |
| `.\rodar prd` | `./rodar.sh prd` | Tudo em prd |
| `.\rodar hml smoke` | `./rodar.sh hml smoke` | Só os testes com a tag `@smoke` |

Ao terminar, o relatório Allure abre no navegador. No Prompt de Comando (cmd), o `.\` é opcional.

Sem o atalho: `.\mvnw test -Dkarate.env=hml` e depois `.\mvnw allure:report`.
Pela IDE: rode a classe `RhnetTest` (para prd, adicione `-Dkarate.env=prd` nas VM options).

---

## Relatórios

| Relatório | Onde | Para quê |
|---|---|---|
| **Allure** | `target/allure-report/index.html` | Relatório principal: visão geral, gráficos, falhas por categoria, histórico e tendências. Cada passo traz a requisição e a resposta HTTP e as verificações registradas. |
| **Detalhe técnico (Karate)** | `target/karate-reports/karate-summary.html` | Investigação detalhada de uma falha, passo a passo. |
| **Resumo da execução** | `target/resumo-execucao.md` | Tabela de resultados. No GitHub Actions, aparece direto na página da execução. |

Dados sensíveis (token, CPF, salário e outros) são mascarados em todos os relatórios, conforme a
configuração `logging.mask` do `karate-config.js`.

**Histórico e tendências:** o Allure guarda um resumo de cada execução anterior (status e duração
de cada teste) e o usa para os gráficos de tendência e o histórico de cada cenário. As execuções
anteriores completas **não** são guardadas: o relatório é sempre substituído pelo mais recente.
Localmente, o histórico fica em `.allure/historico-<ambiente>.jsonl`.

### Relatório publicado

A cada execução do pipeline, o relatório Allure é publicado no GitHub Pages, substituindo o anterior:

```
https://<org>.github.io/rhnet-api-tests/        página inicial: resultado e data de hml e prd
https://<org>.github.io/rhnet-api-tests/hml/    último relatório de homologação
https://<org>.github.io/rhnet-api-tests/prd/    último relatório de produção
```

- Só o **último relatório** de cada ambiente fica acessível, com as tendências das execuções anteriores.
- A branch `gh-pages` é recriada a cada publicação com um único commit: nem o histórico do Git
  guarda versões anteriores dos relatórios.
- O histórico de tendências fica na pasta `.historico/` da branch, que o GitHub Pages não publica.
- A publicação é feita por `.github/scripts/publicar-relatorio.sh`.

---

## Atualizando as specs

Sempre que a API mudar em um ambiente:

1. Baixe a spec do swagger interno daquele ambiente, por exemplo:
   ```bash
   curl -fsSL "https://api-rhnet-hml.sci.com.br/docs?api-docs.json" -o spec/hml/rhnetsocial.json
   ```
2. Revise em https://editor.swagger.io e compare com a versão anterior (`git diff spec/`).
3. Atualize o `INFO.md` do ambiente (primeira linha e histórico).
4. Commite spec e INFO juntos, em um PR: `spec(hml): atualiza para X.Y.Z (AAAA-MM-DD)`.

Comparar `spec/hml/` com `spec/prd/` mostra o que vai entrar em produção no próximo deploy.

---

## Escrevendo testes

1. Copie um modelo de `src/test/java/rhnet/modelos/` para `features/<área>/<recurso>.feature`:
   - `modelo-recurso.feature`: regras, filtros e validações de um recurso
   - `modelo-fluxo.feature`: ciclo criar -> consultar -> atualizar -> remover, com limpeza
2. Troque os marcadores (`RECURSO`, `CAMPO_ID` etc.) pelos nomes reais da spec.
3. Remova o `@ignore` e aplique as tags.

### Padrão de escrita

Os relatórios são lidos por QA e desenvolvimento, então cada cenário deve ser compreensível sem abrir o código:

```gherkin
@regressao
Scenario: Consulta sem sistema_id é rejeitada com erro de validação (400)
  O sistema_id é obrigatório. A API deve recusar a consulta e indicar
  o campo faltante em "erros.sistema_id".

  When method get
  Then status 400
  And match response contains { sucesso: false, status: 400 }
  * registrar('Consulta rejeitada como esperado. Mensagem da API: "' + response.erros.sistema_id[0] + '"')
  * validarContrato()
```

- **Título:** o que é feito e o que se espera, com o status quando relevante.
- **Descrição** (logo abaixo do título): a regra de negócio verificada, em uma ou duas frases.
- **`registrar(...)`:** nos pontos-chave, o que foi confirmado, com os valores reais.
- **`validarContrato()`:** após cada resposta.

### Tags

| Tag | Uso |
|---|---|
| `@smoke` | Essencial e rápido; indica que a API está de pé |
| `@regressao` | Regras de negócio detalhadas |
| `@fluxo` | Fluxos completos (criar -> remover) |
| `@ignore` | Features auxiliares ou modelos; nunca executam diretamente |

### Convenções

1. **Uma feature por recurso**, nomeada pelo recurso da API.
2. **Todo cenário segue o padrão de escrita acima.**
3. **Toda resposta testada chama `validarContrato()`** logo após o `status`.
4. **Nada de ID fixo.** Busque um registro existente e use o ID dele; os dados de hml e prd são diferentes.
5. **Quem cria, remove.** O ID vai para `criados` antes de qualquer verificação, e o `afterScenario` limpa.
6. **Só contas de teste e dados sintéticos, com o prefixo `QA AUTO`.** Nunca use dados reais (LGPD).
7. **Credenciais só em variáveis de ambiente ou secrets.**
8. **Exceção de contrato só com motivo**, registrada em `contrato-ignorar.txt`.

---

## Pipeline

**Environments** (Settings → Environments): crie `hml` e `prd`, cada um com os secrets
`SCI_PARCEIRO_TOKEN` e `SCI_CLIENTE_TOKEN` daquele ambiente.

**GitHub Pages** (uma vez, após a primeira execução do pipeline, que cria a branch `gh-pages`):
Settings → Pages → *Build and deployment* → Source: **Deploy from a branch** → Branch: **gh-pages** / **(root)**.

> **Visibilidade:** confira em Settings → Pages quem pode acessar o site. Em planos sem controle
> de acesso ao Pages, o site de um repositório privado fica **público**. Os relatórios mascaram
> dados sensíveis, mas mostram endpoints, parâmetros e respostas da API. Publique apenas se o
> acesso estiver restrito à organização (ou se o time aceitar essa exposição).

Se a publicação falhar por falta de permissão, habilite em Settings → Actions → General →
*Workflow permissions* a opção **Read and write permissions**.

**Disparo após deploy**: ao final do pipeline dos devs, use `deploy-hml` ou `deploy-prd`:

```bash
curl -X POST \
  -H "Authorization: Bearer $GH_TOKEN_QA" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<org>/rhnet-api-tests/dispatches \
  -d '{"event_type":"deploy-hml","client_payload":{"versao":"'"$VERSAO"'"}}'
```

**Execução manual**: Actions → *API Tests* → *Run workflow*, escolhendo ambiente e tags.

**Resultado de cada execução:** o resumo aparece na página da execução (aba Actions), com o link
do relatório publicado.

> Se as APIs só forem acessíveis pela rede interna, use um runner self-hosted.
> O runner também precisa de acesso a nodejs.org e registry.npmjs.org na primeira geração do
> relatório Allure (depois, o cache é reaproveitado).
