@dependentes
Feature: Dependentes - exclusão (DELETE /api/v1/dependentes)
  O sistema de folha exclui dependentes em qualquer situação. As demais origens só excluem
  dependentes sem vínculo com o sistema de folha (sem v_dependente_id) e nas situações
  nao_liberado ou recusado. O dependente precisa pertencer ao cliente/empresa informados.
  A exclusão não pode ser desfeita.

  Background:
    * url baseUrl
    * path '/api/v1/dependentes'
    * def criados = []
    * configure afterScenario = limparCriados

  @smoke
  Scenario Outline: Integração externa exclui dependente não liberado (cliente <cliente>)

    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == null
    * registrar('Dependente ' + dependente.dependente_id + ' (nao_liberado) excluído por ' + s.nome + ' e não aparece mais na consulta.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Integração externa exclui dependente recusado (cliente <cliente>)

    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    * prepararSituacao(dependente.dependente_id, '<cliente>', 'recusado')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == null
    * registrar('Dependente recusado ' + dependente.dependente_id + ' excluído pela integração externa.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Integração externa não exclui dependente <situacao> (cliente <cliente>)

    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    * prepararSituacao(dependente.dependente_id, '<cliente>', '<situacao>')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == '#notnull'
    * registrar('Exclusão externa de dependente <situacao> recusada. Mensagem da API: "' + response.mensagem + '"')

    Examples:
      | cliente | situacao              |
      | 52      | liberado              |
      | 52      | aguardando_integracao |
      | 52      | integrado             |
      | 19      | liberado              |
      | 19      | aguardando_integracao |
      | 19      | integrado             |

  @regressao @permissoes
  Scenario Outline: Integração externa não exclui dependente vinculado ao sistema de folha (cliente <cliente>)
    Dependente cadastrado pelo sistema de folha tem v_dependente_id: mesmo não liberado,
    só o sistema de folha pode excluí-lo.

    * def dependente = criarDependente(sessoes['sistema-<cliente>'])
    * def s = usarSessao('parceiro-<cliente>')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 400
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == '#notnull'
    * registrar('Exclusão externa do dependente ' + dependente.dependente_id + ' (com v_dependente_id) recusada.')

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Sistema de folha exclui dependente <situacao> (cliente <cliente>)

    * def s = usarSessao('sistema-<cliente>')
    * def dependente = criarDependente(s)
    * prepararSituacao(dependente.dependente_id, '<cliente>', '<situacao>')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == null
    * registrar('Sistema de folha excluiu o dependente ' + dependente.dependente_id + ' na situação <situacao>.')

    Examples:
      | cliente | situacao              |
      | 52      | nao_liberado          |
      | 52      | liberado              |
      | 52      | aguardando_integracao |
      | 52      | integrado             |
      | 19      | liberado              |
      | 19      | integrado             |

  @regressao
  Scenario: Exclusão de dependente inexistente é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: 999999999 }
    When method delete
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()

  @regressao
  Scenario Outline: Exclusão sem o campo obrigatório <campo> é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    * def corpo = { empresa_id: '#(s.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    * remove corpo.<campo>
    Given request corpo
    When method delete
    Then status 400
    And match response.erros.<campo> == '#[_ > 0] #string'
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual == '#notnull'

    Examples:
      | campo         |
      | empresa_id    |
      | dependente_id |

  @regressao @permissoes
  Scenario: Exclusão de dependente de outro cliente é rejeitada e o registro é preservado

    * def dependenteOutroCliente = criarDependente(sessoes['parceiro-19'])
    * def s = usarSessao('parceiro-52')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: '#(dependenteOutroCliente.dependente_id)' }
    When method delete
    Then status 400
    * validarContrato()

    Given path '/api/v1/dependentes'
    And request { empresa_id: '#(outraEmpresa(s))', dependente_id: '#(dependenteOutroCliente.dependente_id)' }
    When method delete
    Then status 403
    * validarContrato()

    * def atual = consultarDependente(sessoes['parceiro-19'], dependenteOutroCliente.dependente_id)

    And match atual == '#notnull'
    * registrar('Dependente do cliente 19 preservado após tentativas de exclusão pela sessão do cliente 52 (400 e 403).')

  @regressao @seguranca
  Scenario: Exclusão sem token de acesso é rejeitada (401)

    * def dependente = criarDependente(sessoes['parceiro-52'])
    Given request { empresa_id: '#(sessoes["parceiro-52"].empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 401
    * validarContrato()
