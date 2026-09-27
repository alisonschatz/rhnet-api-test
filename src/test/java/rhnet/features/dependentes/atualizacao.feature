@dependentes
Feature: Dependentes - atualização (PUT /api/v1/dependentes)
  Atualiza um dependente, localizado pelo dependente_id. Todos os campos devem ser enviados:
  os campos enviados vazios são limpos. Editar fora do sistema de folha devolve a situação para
  nao_liberado. Dependentes em aguardando_integracao só podem ser editados pelo sistema de folha.

  Background:
    * url baseUrl
    * path '/api/v1/dependentes'
    * def criados = []
    * configure afterScenario = limparCriados
    * def Dados = Java.type('rhnet.support.dados.GeradorDados')

  @smoke
  Scenario Outline: Edição dos dados do dependente é gravada (<sessao>)

    * def s = usarSessao('<sessao>')
    * def dependente = criarDependente(s)
    * def novoNome = Dados.nome()
    * def payload = edicaoDependente(dependente, s, { nome: novoNome, descricao_dependencia: 'Editado - QA AUTO', grau_parentesco_id: 1 })
    Given request payload
    When method put
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.retorno contains { dependente_id: '#(dependente.dependente_id)', nome: '#(novoNome)', descricao_dependencia: 'Editado - QA AUTO', grau_parentesco_id: 1 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual contains { nome: '#(novoNome)', grau_parentesco_id: 1 }
    * registrar('Dependente ' + dependente.dependente_id + ' editado por ' + s.nome + ': nome e grau de parentesco atualizados.')

    Examples:
      | sessao      |
      | parceiro-52 |
      | parceiro-19 |
      | sistema-52  |
      | sistema-19  |

  @regressao @permissoes
  Scenario Outline: Edição pela integração externa devolve o dependente liberado para não liberado (cliente <cliente>)

    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    * definirSituacao(s, dependente.dependente_id, 'liberado')
    Given request edicaoDependente(dependente, s, { descricao_dependencia: 'Editado após liberação - QA AUTO' })
    When method put
    Then status 200
    And match response.retorno.situacao == 'nao_liberado'
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'nao_liberado'
    * registrar('Após a edição pela integração externa, o dependente ' + dependente.dependente_id + ' voltou de liberado para nao_liberado.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Edição pelo sistema de folha mantém a situação liberado (cliente <cliente>)

    * def s = usarSessao('sistema-<cliente>')
    * def dependente = criarDependente(s)
    * definirSituacao(s, dependente.dependente_id, 'liberado')
    Given request edicaoDependente(dependente, s, { descricao_dependencia: 'Editado pela folha - QA AUTO' })
    When method put
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual contains { situacao: 'liberado', descricao_dependencia: 'Editado pela folha - QA AUTO' }
    * registrar('Edição pelo sistema de folha manteve o dependente ' + dependente.dependente_id + ' como liberado.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Dependente aguardando integração só pode ser editado pelo sistema de folha (cliente <cliente>)

    * def parceiro = sessoes['parceiro-<cliente>']
    * def sistema = sessoes['sistema-<cliente>']
    * def dependente = criarDependente(sistema)
    * prepararSituacao(dependente.dependente_id, '<cliente>', 'aguardando_integracao')

    # Integração externa: recusada
    * usarSessao('parceiro-<cliente>')
    Given request edicaoDependente(dependente, parceiro, { descricao_dependencia: 'Tentativa externa - QA AUTO' })
    When method put
    Then assert responseStatus == 400 || responseStatus == 403
    * registrar('Edição externa de dependente aguardando integração recusada (status ' + responseStatus + '). Mensagem: "' + response.mensagem + '"')
    * validarContrato()
    * def atual = consultarDependente(sistema, dependente.dependente_id)
    And match atual.descricao_dependencia != 'Tentativa externa - QA AUTO'

    # Sistema de folha: permitida
    * usarSessao('sistema-<cliente>')
    Given path '/api/v1/dependentes'
    And request edicaoDependente(dependente, sistema, { descricao_dependencia: 'Editado pela folha - QA AUTO' })
    When method put
    Then status 200
    * validarContrato()
    * registrar('O sistema de folha editou o dependente ' + dependente.dependente_id + ' em aguardando_integracao.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao
  Scenario: Campos enviados vazios são limpos
    A API exige todos os campos: os que forem enviados vazios são apagados do cadastro.

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    Given request edicaoDependente(dependente, s, { descricao_dependencia: null, mes_formacao_ensino_superior: null, incapaz: null })
    When method put
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.descricao_dependencia == '##null'
    And match atual.nome == dependente.nome
    * registrar('Campos enviados vazios foram limpos; os demais foram mantidos.')

  @regressao
  Scenario: Edição de dependente inexistente é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    Given request edicaoDependente(dependente, s, { dependente_id: 999999999 })
    When method put
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()

  @regressao
  Scenario Outline: Edição sem o campo obrigatório <campo> é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    * def payload = edicaoDependente(dependente, s)
    * remove payload.<campo>
    Given request payload
    When method put
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.<campo> == '#[_ > 0] #string'
    * registrar('Mensagem da API: "' + response.erros.<campo>[0] + '"')
    * validarContrato()

    Examples:
      | campo                       |
      | dependente_id               |
      | empresa_id                  |
      | funcionario_contribuinte_id |
      | nome                        |

  @regressao
  Scenario Outline: Edição com <caso> é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    Given request edicaoDependente(dependente, s, <alteracao>)
    When method put
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.nome == dependente.nome

    Examples:
      | caso                                  | alteracao                            |
      | grau_parentesco_id fora da lista (10) | { grau_parentesco_id: 10 }           |
      | nome acima de 255 caracteres          | { nome: Dados.texto(256) }           |
      | nascimento_data inexistente           | { nascimento_data: '2020-02-30' }    |

  @regressao @permissoes
  Scenario: Edição de dependente de outro cliente é rejeitada
    Com a empresa do próprio usuário, o dependente de outro cliente não é encontrado (400);
    com a empresa do outro cliente, o acesso é negado (403).

    * def dependenteOutroCliente = criarDependente(sessoes['parceiro-19'])
    * def s = usarSessao('parceiro-52')
    Given request edicaoDependente(dependenteOutroCliente, s, { empresa_id: s.empresaId, funcionario_contribuinte_id: s.funcionarioId })
    When method put
    Then status 400
    * validarContrato()

    Given path '/api/v1/dependentes'
    And request edicaoDependente(dependenteOutroCliente, s)
    When method put
    Then status 403
    * validarContrato()
    * registrar('Dependente do cliente 19 não pôde ser editado pela sessão do cliente 52 (400 com a própria empresa, 403 com a empresa alheia).')

  @regressao @seguranca
  Scenario: Edição sem token de acesso é rejeitada (401)

    * def dependente = criarDependente(sessoes['parceiro-52'])
    Given request edicaoDependente(dependente, sessoes['parceiro-52'])
    When method put
    Then status 401
    * validarContrato()
