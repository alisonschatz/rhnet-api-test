# RH NET Social - Testes de API

Testes automatizados da API **RH NET Social**, em repositório independente do código da
aplicação. Rodam em **homologação (hml)** e em **produção (prd)**, a cada deploy e sob demanda.

**Stack:** Karate 1.5 · Java 21 · Maven (via Maven Wrapper) · GitHub Actions

---

## Como funciona

1. O dev faz deploy e o pipeline dele dispara este repositório, informando o ambiente.
2. O Karate faz login **uma vez** na API de auth daquele ambiente e roda as features em paralelo.
3. Cada resposta testada é conferida contra a **spec oficial daquele ambiente**
   (`spec/<ambiente>/`), baixada e validada pelo QA.
4. O relatório HTML fica disponível no pipeline.

### APIs e specs

O alvo dos testes é a **RH NET Social**. Ela depende da **API de autenticação**, que também
tem seu contrato validado. Cada API tem uma spec por ambiente:

```
spec/
├── hml/
│   ├── rhnetsocial.json    # RH NET Social em homologação
│   ├── auth.json           # Auth em homologação
│   └── INFO.md             # data, versão, responsável e histórico das duas
└── prd/
    ├── rhnetsocial.json
    ├── auth.json
    └── INFO.md
```

Nas features, `validarContrato()` usa a spec da RH NET Social e `validarContrato('auth')` usa a
da API de auth. O ambiente é escolhido automaticamente.

### Hml e prd sem distinção

Todos os testes rodam nos dois ambientes, inclusive os que criam, alteram e removem dados.
Isso é seguro porque cada ambiente usa **usuários e contas exclusivos para teste**. Mesmo assim,
todo dado criado é removido ao final do cenário (ver convenções).

---

## Estrutura

```
├── ambientes.json                      # URLs de cada ambiente (hml, prd)
├── .env.example                        # modelo do .env.hml / .env.prd (credenciais)
├── spec/                               # specs oficiais por ambiente (ver acima)
├── rodar.cmd / rodar.sh                # atalho para rodar localmente
├── pom.xml                             # dependências do projeto
├── mvnw / mvnw.cmd / .mvn/             # Maven Wrapper (não precisa instalar Maven)
├── .github/workflows/api-tests.yml     # pipeline (hml e prd)
└── src/test/
    ├── resources/
    │   └── contrato-ignorar.txt        # exceções de contrato aceitas (com motivo)
    └── java/
        ├── karate-config.js            # configuração global: ambiente, login, validarContrato()
        ├── logback-test.xml            # configuração de logs
        └── rhnet/
            ├── RhnetTest.java          # ponto de execução (paralelo, filtro por tags)
            │
            ├── features/               # OS TESTES, uma pasta por área da API
            │   ├── auth/               #   login
            │   └── consultas/          #   bancos, cadastros básicos
            │
            ├── modelos/                # modelos para novas features (não executam)
            │
            └── support/                # infraestrutura, organizada por responsabilidade
                ├── auth/               #   login da execução e utilitários de autenticação
                │   ├── obter-token.feature
                │   └── Autenticacao.java       Basic Auth e leitura do JWT
                ├── contrato/           #   validação de respostas contra a spec
                │   ├── ValidadorContrato.java  carrega a spec e valida
                │   ├── MensagensContrato.java  monta as mensagens do relatório
                │   └── LocalizadorJson.java    localiza linha e caminho na spec
                ├── dados/              #   massa de dados sintética
                │   └── GeradorDados.java       CPF válido, nomes, datas
                └── log/                #   logs
                    └── MascaradorLog.java      oculta token, CPF, salário (LGPD)
```

Onde colocar algo novo:
- **Um teste:** `features/<área>/<recurso>.feature`.
- **Infraestrutura reutilizável:** a pasta de `support/` da responsabilidade correspondente,
  ou uma pasta nova se for uma responsabilidade nova (ex.: `support/arquivos/` para uploads).

### Variáveis disponíveis nas features

Definidas em `karate-config.js`, sem precisar declarar nada:

| Variável | Conteúdo |
|---|---|
| `baseUrl`, `authUrl` | URLs da RH NET Social e da API de auth do ambiente |
| `ambiente` | `hml` ou `prd` |
| `token` | JWT do usuário de teste |
| `sessao` | Dados do JWT, ex.: `sessao.sistemaId`, `sessao.usuario.dados.empresasVinculadas` |
| `validarContrato()` | Valida a última resposta contra a spec (`'auth'` para a API de auth) |

---

## Rodando localmente

Pré-requisito (uma vez só): **Java 21** instalado e acesso à rede das APIs (VPN, se for o caso).

- Windows: `winget install EclipseAdoptium.Temurin.21.JDK`
- O **Maven não precisa ser instalado**: o projeto usa o [Maven Wrapper](https://maven.apache.org/wrapper/)
  oficial (`mvnw`), que baixa automaticamente a versão fixada em `.mvn/wrapper/maven-wrapper.properties`.
  Assim, todos no time e o pipeline usam exatamente a mesma versão.

**1. Credenciais:** copie o `.env.example` para `.env.hml` (e `.env.prd`, se for usar) e
preencha os dois tokens.

**2. Rode:**

| Windows (PowerShell) | Linux / Mac | O que faz |
|---|---|---|
| `.\rodar` | `./rodar.sh` | Tudo em hml |
| `.\rodar prd` | `./rodar.sh prd` | Tudo em prd |
| `.\rodar hml smoke` | `./rodar.sh hml smoke` | Só os testes com a tag `@smoke` |

No Prompt de Comando (cmd), o `.\` é opcional.

Ao terminar, o relatório abre sozinho no navegador.

As URLs de cada ambiente ficam em `ambientes.json`, na raiz do projeto.

Sem o atalho, o comando equivalente é `.\mvnw test -Dkarate.env=hml` (ou `./mvnw` no Linux/Mac).

Pela IDE: rode a classe `RhnetTest` normalmente. As credenciais são lidas do `.env.hml`;
para prd, adicione `-Dkarate.env=prd` nas VM options.

---

## Atualizando as specs

Sempre que uma API mudar em um ambiente:

1. Baixe a spec do swagger interno daquele ambiente para o arquivo correspondente, por exemplo:
   ```bash
   curl -fsSL "https://api-rhnet-hml.sci.com.br/docs?api-docs.json" -o spec/hml/rhnetsocial.json
   ```
2. Revise: abra em https://editor.swagger.io, confira se não há erros e se as mudanças batem
   com o combinado. Use `git diff spec/` para ver o que mudou.
3. Atualize o `INFO.md` do ambiente (primeira linha, tabela e histórico).
4. Commite spec e INFO juntos, em um PR:
   ```bash
   git commit -am "spec(hml/rhnetsocial): atualiza para X.Y.Z (AAAA-MM-DD)"
   ```

Dica: comparar `spec/hml/` com `spec/prd/` mostra exatamente o que vai entrar em produção
no próximo deploy.

---

## Escrevendo testes

1. Copie um modelo de `src/test/java/rhnet/modelos/` para `features/<area>/<recurso>.feature`:
   - `modelo-recurso.feature`: regras, filtros e validações de um recurso
   - `modelo-fluxo.feature`: ciclo criar -> consultar -> atualizar -> remover, com limpeza
2. Troque os marcadores (`RECURSO`, `CAMPO_ID` etc.) pelos nomes reais da spec.
3. Remova o `@ignore` e aplique as tags.

### Tags

| Tag | Uso |
|---|---|
| `@smoke` | Essencial e rápido; indica que a API está de pé |
| `@regressao` | Regras de negócio detalhadas |
| `@fluxo` | Fluxos completos (criar -> remover) |
| `@ignore` | Features auxiliares ou modelos; nunca executam diretamente |

### Convenções

1. **Uma feature por recurso**, nomeada pelo recurso da API.
2. **O cenário descreve o comportamento esperado** ("Sem X retorna 400"), não a implementação.
3. **Toda resposta testada chama `validarContrato()`** (ou `validarContrato('auth')`) logo após o `status`.
4. **Nada de ID fixo.** Busque um registro existente e use o ID dele; os dados de hml e prd são diferentes.
5. **Quem cria, remove.** O ID vai para `criados` antes de qualquer assert, e o `afterScenario` limpa.
6. **Só contas de teste e dados sintéticos, com o prefixo `QA AUTO`.** Nunca use dados reais (LGPD).
7. **Credenciais só em variáveis de ambiente ou secrets.**
8. **Exceção de contrato só com motivo**, registrada em `contrato-ignorar.txt`.

---

## Pipeline

**Environments** (Settings → Environments): crie `hml` e `prd`, cada um com os secrets
`SCI_PARCEIRO_TOKEN` e `SCI_CLIENTE_TOKEN` daquele ambiente. No `prd`, você pode exigir
aprovação manual antes de cada execução.

**Disparo após deploy**: ao final do pipeline dos devs, use `deploy-hml` ou `deploy-prd`:

```bash
curl -X POST \
  -H "Authorization: Bearer $GH_TOKEN_QA" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<org>/rhnet-api-tests/dispatches \
  -d '{"event_type":"deploy-hml","client_payload":{"versao":"'"$VERSAO"'"}}'
```

**Execução manual**: Actions → *API Tests* → *Run workflow*, escolhendo ambiente e tags.

> Se as APIs só forem acessíveis pela rede interna, use um runner self-hosted.
