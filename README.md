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
├── dados-teste.json                    # massa de teste por ambiente e cliente (colaborador, empresa)
├── .env.example                        # modelo do .env.hml / .env.prd (credenciais)
├── spec/
│   ├── hml/  rhnetsocial.json, INFO.md # spec oficial e histórico de cada ambiente
│   └── prd/  rhnetsocial.json, INFO.md
├── allurerc.mjs                        # configuração do Allure Report (idioma, nome, histórico por ambiente)
├── rodar.cmd / rodar.sh                # atalho para rodar localmente
├── pom.xml                             # dependências do projeto
├── mvnw / mvnw.cmd / .mvn/             # Maven Wrapper (não precisa instalar Maven)
├── .github/
│   ├── workflows/api-tests.yml         # pipeline (hml e prd)
│   ├── scripts/                        # publicação no GitHub Pages
│   │   ├── publicar-relatorio.sh       #   publica o relatório de um ambiente
│   │   ├── gerar_pagina_inicial.py     #   monta a página inicial a partir dos resultados
│   │   └── notificar_discord.py        #   envia o aviso de cada execução ao Discord
│   └── pages/                          # template da página inicial (visual do Allure) e fonte
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
            │   ├── dependentes/        #   consulta, cadastro, atualização e exclusão
            │   └── liberacoes/         #   liberação de dependentes
            │
            ├── modelos/                # modelos para novas features (não executam)
            │
            └── support/                # infraestrutura, organizada por responsabilidade
                ├── auth/               #   autenticação das sessões da execução
                │   ├── obter-tokens.feature    login de todas as sessões (uma vez por execução)
                │   ├── login.feature           login de uma sessão
                │   └── Autenticacao.java       Basic Auth e leitura do JWT
                ├── dependentes/        #   pré-condições e limpeza dos testes de dependentes
                │   └── criar, consultar, liberar, remover (.feature)
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
| `usarSessao(nome)` | Autentica as próximas requisições com a sessão e a retorna (ver [Sessões](#sessões-e-permissões)) |
| `sessoes` | Todas as sessões: `{ nome, tipo, cliente, empresaId, funcionarioId }` |
| `outraEmpresa(sessao)` | Empresa de outro cliente, para testes de acesso indevido |
| `criarDependente`, `consultarDependente`, `prepararSituacao`... | Utilitários de dependentes (lista completa no topo do `karate-config.js`) |
| `validarContrato()` | Valida a última resposta contra a spec da RH NET Social do ambiente |
| `registrar(texto)` | Registra uma verificação em português nos relatórios (Allure e Karate) |

---

## Sessões e permissões

A API se comporta de forma diferente conforme **quem** faz a chamada. Os testes usam quatro sessões,
autenticadas uma única vez por execução:

| Sessão | Usuário (Basic Auth) | Senha | Papel |
|---|---|---|---|
| `parceiro-52` | `SCI_PARCEIRO_TOKEN` | `SCI_CLIENTE_52_TOKEN` | Integração externa, cliente 52 |
| `parceiro-19` | `SCI_PARCEIRO_TOKEN` | `SCI_CLIENTE_19_TOKEN` | Integração externa, cliente 19 |
| `sistema-52` | `SCI_SISTEMA_52_TOKEN` | `SCI_CLIENTE_52_TOKEN` | Sistema de folha (desktop), cliente 52 |
| `sistema-19` | `SCI_SISTEMA_19_TOKEN` | `SCI_CLIENTE_19_TOKEN` | Sistema de folha (desktop), cliente 19 |

Cada cenário escolhe explicitamente a sessão com `usarSessao('parceiro-52')`: não existe sessão
padrão. Quando uma regra vale para mais de um tipo de token ou cliente, o cenário é um
*Scenario Outline* com uma linha por sessão, e o relatório mostra o resultado de cada uma.

Os testes de **acesso indevido** usam os dois clientes: uma sessão do cliente 52 tenta acessar a
empresa ou os dependentes do cliente 19, e vice-versa.

### Regras de dependentes cobertas

| Ação | Integração externa (parceiro) | Sistema de folha |
|---|---|---|
| Cadastrar | Sem `v_dependente_id` (proibido) | Com `v_dependente_id` (obrigatório) |
| Ver `v_dependente_id` | Não trafega | Sim |
| Editar | Devolve a situação para `nao_liberado` | Mantém a situação |
| Editar em `aguardando_integracao` | Recusado | Permitido |
| Excluir | Só `nao_liberado` ou `recusado`, sem `v_dependente_id` | Qualquer situação |
| Definir `aguardando_integracao`, `integrado`, `recusado` | Recusado | Permitido |
| Tirar de `aguardando_integracao` | Recusado | Permitido |
| Consultar com `situacao=liberado` | Sem efeito | Passa os registros para `aguardando_integracao` |

**Limpeza:** todo dependente criado por um teste é excluído ao final do cenário, mesmo em caso de
falha, pela sessão de **sistema** do cliente, a única que exclui em qualquer situação.

### Massa de teste

O `dados-teste.json` define, por ambiente e cliente:

| Campo | Conteúdo |
|---|---|
| `funcionarioContribuinteId` | Colaborador de teste **ativo, sem desligamento e já liberado** (exigência para cadastrar e liberar dependentes) |
| `empresaId` | Opcional. Quando `null`, usa a primeira empresa vinculada ao usuário no token |

Sem o colaborador preenchido, os testes que criam dependentes param com uma mensagem indicando
o que falta.

---

## Rodando localmente

Pré-requisito (uma vez só): **Java 21 ou superior** e acesso à rede das APIs (VPN, se for o caso).

- Windows: `winget install EclipseAdoptium.Temurin.21.JDK`
- O **Maven não precisa ser instalado**: o Maven Wrapper (`mvnw`) baixa a versão fixada no projeto.
- O **Allure não precisa ser instalado**: o plugin baixa o Allure e um Node.js próprio para a pasta
  `.allure` na primeira geração do relatório.

**1. Credenciais:** copie o `.env.example` para `.env.hml` (e `.env.prd`, se for usar) e preencha os
cinco tokens.

**2. URLs e massa de teste:** confira o `ambientes.json` e preencha o `dados-teste.json` (ver
[Massa de teste](#massa-de-teste)).

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
- O pipeline publica o site diretamente no GitHub Pages. A branch `relatorios` guarda o último
  relatório de cada ambiente e o histórico entre execuções; ela é recriada a cada publicação com um
  único commit, então nem o histórico do Git guarda versões anteriores dos relatórios.
- O histórico de tendências fica na pasta `.historico/` da branch, que não é incluída no site.
- A publicação é feita por `.github/scripts/publicar-relatorio.sh`.

**Página inicial:** um cartão por ambiente com o resultado, os números de cenários (total, que
passaram e que falharam), data, duração, versão implantada, spec em uso e os links para o relatório
e para a execução no GitHub Actions. Segue o mesmo sistema de design do Allure Report (fonte, cores,
temas claro e escuro). Para alterar textos ou layout, edite `.github/pages/index.html`; o conteúdo
dos cartões é montado por `.github/scripts/gerar_pagina_inicial.py`.

**Idioma:** os relatórios Allure abrem em português por padrão (`allurerc.mjs`). Quem trocar o idioma
no próprio relatório mantém a escolha, que fica salva no navegador.

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

O pipeline roda os testes no GitHub Actions e publica o relatório no GitHub Pages. A configuração
é feita uma única vez, seguindo os passos abaixo na ordem.

### Passo a passo da configuração

**1. Subir o projeto para o GitHub**

Crie o repositório (ex.: `rhnet-api-tests`) e envie o projeto para a branch principal (`main`).
O workflow só é reconhecido pelo GitHub quando está na branch principal.

**2. Cadastrar as credenciais de cada ambiente**

Em **Settings → Environments**:

1. Clique em **New environment**, digite `hml` e confirme.
2. Em **Environment secrets**, clique em **Add environment secret** e cadastre os tokens de hml:
   - `SCI_PARCEIRO_TOKEN`
   - `SCI_SISTEMA_52_TOKEN` e `SCI_SISTEMA_19_TOKEN`
   - `SCI_CLIENTE_52_TOKEN` e `SCI_CLIENTE_19_TOKEN`
3. Repita para um environment chamado `prd`, com as credenciais de produção.

Os nomes dos environments e dos secrets precisam ser exatamente esses. Opcionalmente, no
environment `prd`, marque **Required reviewers** para exigir aprovação antes de cada execução.

**3. Permitir que o pipeline publique o relatório**

Em **Settings → Actions → General → Workflow permissions**, selecione
**Read and write permissions** e salve. Se a opção estiver bloqueada, ela é definida pela
organização: peça a um administrador para liberar.

**4. Ativar o GitHub Pages**

Em **Settings → Pages**, em **Build and deployment → Source**, selecione **GitHub Actions**.
Não é preciso escolher branch: o próprio pipeline publica o site.

**5. Rodar o pipeline pela primeira vez**

Em **Actions**, selecione **API Tests - RH NET Social**, clique em **Run workflow**, escolha o
ambiente e confirme. Ao final, a execução terá dois jobs concluídos: **Testes de API** e
**Publicar relatório**, com o link do site no resumo. O endereço também aparece em
**Settings → Pages**: `https://<org>.github.io/rhnet-api-tests/`.

**6. Conferir quem pode acessar o site**

Ainda em **Settings → Pages**, confira a visibilidade do site.

> Em planos sem controle de acesso ao Pages, o site de um repositório privado fica **público na
> internet**. Os relatórios mascaram dados sensíveis, mas mostram endpoints, parâmetros e respostas
> da API. No GitHub Enterprise Cloud, selecione a visibilidade **Private** para restringir o acesso
> a quem tem acesso ao repositório. Sem essa opção, avalie com o time antes de manter o site ativo.

**7. Conferir o resultado**

Abra o endereço do site: a página inicial mostra o cartão do ambiente executado, com o link para o
relatório. A partir daqui, toda execução do pipeline atualiza o site automaticamente.

**8. (Opcional) Disparar os testes a cada deploy**

Para rodar os testes automaticamente após cada deploy, o pipeline dos devs chama este repositório:

1. Crie um token em **GitHub → Settings (do seu perfil) → Developer settings → Personal access tokens
   → Fine-grained tokens**, com acesso somente a este repositório e a permissão
   **Contents: Read and write**.
2. Cadastre esse token como secret no pipeline dos devs (ex.: `GH_TOKEN_QA`).
3. Ao final do deploy, o pipeline dos devs executa, usando `deploy-hml` ou `deploy-prd`:

```bash
curl -X POST \
  -H "Authorization: Bearer $GH_TOKEN_QA" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<org>/rhnet-api-tests/dispatches \
  -d '{"event_type":"deploy-hml","client_payload":{"versao":"'"$VERSAO"'"}}'
```

**9. (Opcional) Receber avisos no Discord**

A cada execução, o pipeline pode enviar um aviso a um canal do Discord com o resultado e o link do
relatório:

1. No Discord, nas configurações do canal (ex.: `#qa-alertas`): **Integrações → Webhooks →
   Novo Webhook**. Dê um nome (ex.: *QA Bot*) e clique em **Copiar URL do Webhook**. Trate essa URL
   como senha: quem a tiver pode enviar mensagens ao canal.
2. No GitHub, em **Settings → Secrets and variables → Actions → New repository secret**, crie o
   secret `DISCORD_WEBHOOK_URL` com a URL copiada.

Pronto: a próxima execução já envia o aviso. Sem o secret, o passo é ignorado sem erro.

O aviso segue as cores do relatório e traz os números da execução e os links:

| Situação | Aviso |
|---|---|
| Todos os testes passaram | ✅ verde, com cenários, duração e versão implantada |
| Algum teste falhou | ❌ vermelho, com "X de Y cenário(s) falharam" |
| Os testes não chegaram a rodar | ⚠️ cinza, com o link da execução para ver o erro |

Uma falha no envio ao Discord (URL inválida, Discord fora do ar) gera só um aviso no log da
execução e nunca altera o resultado do pipeline.

### No dia a dia

- **Execução manual:** Actions → *API Tests - RH NET Social* → *Run workflow*, escolhendo:
  - **Ambiente:** `hml` ou `prd`.
  - **Quais testes executar:** *Todos*, *Smoke* (essenciais e rápidos) ou *Regressão* (regras de negócio).
- **Disparo automático (após deploy):** roda sempre **todos** os testes do ambiente informado.
- **Resultado:** a página da execução (aba Actions) mostra o resumo, com o link do relatório publicado.
- **Status da execução:** fica **vermelho** quando algum teste falha, para sinalizar o problema e
  gerar a notificação do GitHub. O relatório é publicado normalmente, e os avisos da execução mostram,
  por exemplo: *"2 de 5 cenários falharam em PRD. Relatório: https://..."*. O deploy dos devs não é
  afetado: o disparo não espera o resultado dos testes.
- **Relatório:** sempre o mais recente de cada ambiente, no endereço do site.

### Problemas comuns

| Sintoma | Causa provável |
|---|---|
| O workflow não aparece na aba Actions | O arquivo não está na branch principal |
| Falha em "Executar testes" com erro de credenciais | Secrets ausentes ou com nome diferente no environment |
| Falha em "Montar o site" com erro 403 | Passo 3 não aplicado (permissão de escrita) |
| Falha em "Publicar no GitHub Pages" (Pages não encontrado) | Passo 4 não aplicado (Source: GitHub Actions) |
| Falha em "Publicar no GitHub Pages" por regra do environment | Em Settings → Environments → github-pages, permita a branch principal |
| Site não abre (404) | Publicação ainda em andamento: aguarde alguns minutos |
| Timeout ou conexão recusada nos testes | A API não é acessível pela internet: use um runner self-hosted na rede interna |
| Relatório Allure não gerado | O runner não acessa nodejs.org e registry.npmjs.org (necessários na primeira geração) |
| Aviso "Aviso no Discord não enviado" | URL do webhook inválida ou webhook apagado no Discord: recrie e atualize o secret |
