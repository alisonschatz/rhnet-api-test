@dependentes
Feature: Dependentes - consulta (GET /api/v1/dependentes)
  Lista paginada de dependentes da empresa, com filtros por dependente_id, funcionario_contribuinte_id,
  v_dependente_id, alterado_data e situacao. O v_dependente_id (código no sistema de folha) só
  trafega em requisições do sistema de folha. Consultas do sistema de folha com situacao=liberado
  passam os registros retornados para aguardando_integracao.

  Background:
    * url baseUrl
    * path '/api/v1/dependentes'
    * def criados = []
    * configure afterScenario = limparCriados

  @smoke
  Scenario Outline: Consulta da empresa retorna a lista paginada (<sessao>)
    A listagem é permitida para as integrações externas e para o sistema de folha,
    em cada cliente, sempre sobre a empresa vinculada ao usuário.

    * def s = usarSessao('<sessao>')
    Given param empresa_id = s.empresaId
    When method get
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.paginacao contains { pagina_atual: '#number', total: '#number' }
    And match response.retorno == '#array'
    * registrar('Consulta com a sessão ' + s.nome + ' retornou ' + response.paginacao.total + ' dependente(s) na empresa ' + s.empresaId + '.')
    * validarContrato()

    Examples:
      | sessao      |
      | parceiro-52 |
      | parceiro-19 |
      | sistema-52  |
      | sistema-19  |

  @regressao
  Scenario: Filtro por dependente_id retorna somente o dependente informado
    O teste cadastra um dependente e o consulta pelo ID.

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    Given params { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method get
    Then status 200
    And match response.retorno == '#[1]'
    And match response.retorno[0] contains { dependente_id: '#(dependente.dependente_id)', nome: '#(dependente.nome)', situacao: 'nao_liberado' }
    * registrar('Filtro por dependente_id = ' + dependente.dependente_id + ' retornou apenas o dependente cadastrado.')
    * validarContrato()

  @regressao
  Scenario: Filtro por funcionario_contribuinte_id retorna apenas dependentes do colaborador

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    Given params { empresa_id: '#(s.empresaId)', funcionario_contribuinte_id: '#(s.funcionarioId)', per_page: 100 }
    When method get
    Then status 200
    And match each response.retorno contains { funcionario_contribuinte_id: '#(s.funcionarioId)' }
    And match response.retorno[*].dependente_id contains dependente.dependente_id
    * registrar('Todos os ' + response.retorno.length + ' dependente(s) retornados pertencem ao colaborador ' + s.funcionarioId + '.')
    * validarContrato()

  @regressao @permissoes
  Scenario Outline: O código do sistema de folha (v_dependente_id) só aparece para o sistema de folha (cliente <cliente>)
    Dependente cadastrado pelo sistema de folha, com v_dependente_id: o sistema o recebe na consulta,
    a integração externa não.

    * def sistema = sessoes['sistema-<cliente>']
    * def dependente = criarDependente(sistema)
    * def codigo = dependente.v_dependente_id

    # Sistema de folha: recebe o código
    * usarSessao('sistema-<cliente>')
    Given params { empresa_id: '#(sistema.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method get
    Then status 200
    And match response.retorno[0].v_dependente_id == codigo
    * validarContrato()

    # Integração externa: não recebe o código
    * def parceiro = usarSessao('parceiro-<cliente>')
    Given path '/api/v1/dependentes'
    And params { empresa_id: '#(parceiro.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method get
    Then status 200
    And match response.retorno[0].v_dependente_id == '##null'
    * registrar('v_dependente_id ' + codigo + ' visível para o sistema de folha e oculto para a integração externa.')
    * validarContrato()

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao
  Scenario: Paginação respeita a quantidade de registros por página

    * def s = usarSessao('parceiro-52')
    Given params { empresa_id: '#(s.empresaId)', per_page: 1, page: 1 }
    When method get
    Then status 200
    And match response.paginacao contains { registros_por_pagina: 1, pagina_atual: 1 }
    And match response.retorno == '#[_ <= 1]'
    * registrar('Com per_page = 1, a página trouxe ' + response.retorno.length + ' registro(s).')
    * validarContrato()

  @regressao
  Scenario: Consulta sem empresa_id é rejeitada com erro de validação (400)

    * usarSessao('parceiro-52')
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.empresa_id == '#[_ > 0] #string'
    * registrar('Consulta rejeitada. Mensagem da API: "' + response.erros.empresa_id[0] + '"')
    * validarContrato()

  @regressao
  Scenario: Consulta com situação inexistente é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    Given params { empresa_id: '#(s.empresaId)', situacao: 'situacao_inexistente' }
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()

  @regressao @permissoes
  Scenario Outline: Consulta da empresa de outro cliente é negada (<sessao>)
    Um usuário só acessa as empresas vinculadas a ele: a empresa de outro cliente retorna 403.

    * def s = usarSessao('<sessao>')
    Given param empresa_id = outraEmpresa(s)
    When method get
    Then status 403
    And match response contains { sucesso: false, status: 403 }
    * registrar('Acesso à empresa de outro cliente negado para ' + s.nome + '. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()

    Examples:
      | sessao      |
      | parceiro-52 |
      | parceiro-19 |
      | sistema-52  |
      | sistema-19  |

  # Bug: a API responde 'message' em vez de 'mensagem'. Troque A-DEFINIR-1 pelo número do chamado.
  @regressao @seguranca @bug-A-DEFINIR-1
  Scenario: Consulta sem token de acesso é rejeitada (401)

    * def s = sessoes['parceiro-52']
    Given param empresa_id = s.empresaId
    When method get
    Then status 401
    And match response contains { mensagem: '#string' }
    * validarContrato()

  # Bug: a API responde 'message' em vez de 'mensagem'. Troque A-DEFINIR-1 pelo número do chamado.
  @regressao @seguranca @bug-A-DEFINIR-1
  Scenario: Consulta com token inválido é rejeitada (401)

    * def s = sessoes['parceiro-52']
    * configure headers = { Authorization: 'Bearer token-invalido', Accept: 'application/json' }
    Given param empresa_id = s.empresaId
    When method get
    Then status 401
    And match response contains { mensagem: '#string' }
    * validarContrato()

  @fluxo
  Scenario Outline: Consulta do sistema de folha com situacao=liberado assume a integração (cliente <cliente>)
    Regra da API: ao consultar dependentes liberados, o sistema de folha assume a integração e os
    registros retornados passam para aguardando_integracao. O filtro por dependente_id restringe o
    efeito ao dependente do próprio teste.

    * def parceiro = sessoes['parceiro-<cliente>']
    * def dependente = criarDependente(parceiro)
    * definirSituacao(parceiro, dependente.dependente_id, 'liberado')

    * def sistema = usarSessao('sistema-<cliente>')
    Given params { empresa_id: '#(sistema.empresaId)', dependente_id: '#(dependente.dependente_id)', situacao: 'liberado' }
    When method get
    Then status 200
    And match response.retorno[*].dependente_id contains dependente.dependente_id
    * validarContrato()

    * def atual = consultarDependente(parceiro, dependente.dependente_id)
    And match atual.situacao == 'aguardando_integracao'
    * registrar('Após a consulta do sistema de folha, o dependente ' + dependente.dependente_id + ' passou de liberado para aguardando_integracao.')

    Examples:
      | cliente |
      | 52      |
      | 19      |
