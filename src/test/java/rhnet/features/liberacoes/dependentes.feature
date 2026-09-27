@liberacao @dependentes
Feature: Liberação de dependentes (POST /api/v1/liberacoes/dependentes)
  Altera a situação e a observação de liberação de um ou mais dependentes.
  - nao_liberado e liberado: qualquer origem.
  - aguardando_integracao, integrado e recusado: somente o sistema de folha.
  - Dependentes em aguardando_integracao não voltam para nao_liberado nem liberado fora do sistema de folha.
  - Para liberar: cadastro mínimo (funcionario_contribuinte_id, nome, cpf, nascimento_data,
    grau_parentesco_id, tipo_dependencia_id e inicio_dependencia_data), competência não bloqueada
    e colaborador dono já liberado.

  Background:
    * url baseUrl
    * path '/api/v1/liberacoes/dependentes'
    * def criados = []
    * configure afterScenario = limparCriados
    * def Dados = Java.type('rhnet.support.dados.GeradorDados')

  @smoke
  Scenario Outline: Dependente com cadastro completo é liberado (<sessao>)

    * def s = usarSessao('<sessao>')
    * def dependente = criarDependente(s)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'liberado', observacao_liberacao: 'Liberado pelos testes - QA AUTO' }
    When method post
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual contains { situacao: 'liberado', observacao_liberacao: 'Liberado pelos testes - QA AUTO' }
    * registrar('Dependente ' + dependente.dependente_id + ' liberado por ' + s.nome + ', com a observação gravada.')

    Examples:
      | sessao      |
      | parceiro-52 |
      | parceiro-19 |
      | sistema-52  |
      | sistema-19  |

  @regressao
  Scenario Outline: Dependente liberado volta para não liberado (<sessao>)

    * def s = usarSessao('<sessao>')
    * def dependente = criarDependente(s)
    * definirSituacao(s, dependente.dependente_id, 'liberado')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'nao_liberado' }
    When method post
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'nao_liberado'
    * registrar('Dependente ' + dependente.dependente_id + ' voltou de liberado para nao_liberado (' + s.nome + ').')

    Examples:
      | sessao      |
      | parceiro-52 |
      | sistema-19  |

  @regressao
  Scenario: Liberação em lote aplica a mesma situação e observação a todos

    * def s = usarSessao('parceiro-52')
    * def primeiro = criarDependente(s)
    * def segundo = criarDependente(s)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(primeiro.dependente_id)', '#(segundo.dependente_id)'], situacao: 'liberado', observacao_liberacao: 'Lote - QA AUTO' }
    When method post
    Then status 200
    * validarContrato()
    * def atualPrimeiro = consultarDependente(s, primeiro.dependente_id)
    * def atualSegundo = consultarDependente(s, segundo.dependente_id)
    And match atualPrimeiro contains { situacao: 'liberado', observacao_liberacao: 'Lote - QA AUTO' }
    And match atualSegundo contains { situacao: 'liberado', observacao_liberacao: 'Lote - QA AUTO' }
    * registrar('Lote liberado: dependentes ' + primeiro.dependente_id + ' e ' + segundo.dependente_id + '.')

  @regressao @permissoes
  Scenario Outline: Integração externa não pode definir a situação <situacao> (cliente <cliente>)
    As situações aguardando_integracao, integrado e recusado são exclusivas do sistema de folha.

    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: '<situacao>' }
    When method post
    Then assert responseStatus == 400 || responseStatus == 403
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'nao_liberado'
    * registrar('Situação <situacao> recusada para a integração externa (status ' + responseStatus + '); o dependente continua nao_liberado.')

    Examples:
      | cliente | situacao              |
      | 52      | aguardando_integracao |
      | 52      | integrado             |
      | 52      | recusado              |
      | 19      | aguardando_integracao |
      | 19      | integrado             |
      | 19      | recusado              |

  @regressao @permissoes
  Scenario Outline: Sistema de folha define a situação <situacao> (cliente <cliente>)

    * def s = usarSessao('sistema-<cliente>')
    * def dependente = criarDependente(s)
    * definirSituacao(s, dependente.dependente_id, 'liberado')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: '<situacao>', observacao_liberacao: 'Definido pela folha - QA AUTO' }
    When method post
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == '<situacao>'
    * registrar('Sistema de folha definiu a situação <situacao> para o dependente ' + dependente.dependente_id + '.')

    Examples:
      | cliente | situacao              |
      | 52      | aguardando_integracao |
      | 52      | integrado             |
      | 52      | recusado              |
      | 19      | aguardando_integracao |
      | 19      | integrado             |
      | 19      | recusado              |

  @regressao @permissoes
  Scenario Outline: Integração externa não tira o dependente de aguardando integração para <situacao> (cliente <cliente>)

    * def sistema = sessoes['sistema-<cliente>']
    * def s = usarSessao('parceiro-<cliente>')
    * def dependente = criarDependente(s)
    * definirSituacao(s, dependente.dependente_id, 'liberado')
    * definirSituacao(sistema, dependente.dependente_id, 'aguardando_integracao')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: '<situacao>' }
    When method post
    Then assert responseStatus == 400 || responseStatus == 403
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'aguardando_integracao'
    * registrar('Mudança de aguardando_integracao para <situacao> recusada para a integração externa (status ' + responseStatus + ').')

    Examples:
      | cliente | situacao     |
      | 52      | liberado     |
      | 52      | nao_liberado |
      | 19      | liberado     |
      | 19      | nao_liberado |

  @regressao @permissoes
  Scenario Outline: Sistema de folha tira o dependente de aguardando integração (cliente <cliente>)

    * def s = usarSessao('sistema-<cliente>')
    * def dependente = criarDependente(s)
    * prepararSituacao(dependente.dependente_id, '<cliente>', 'aguardando_integracao')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'nao_liberado' }
    When method post
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'nao_liberado'

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao
  Scenario Outline: Liberação sem o campo <campo> no cadastro é rejeitada (400)
    Para liberar, o cadastro mínimo precisa estar completo.

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s, { <campo>: null })
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'liberado' }
    When method post
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.situacao == 'nao_liberado'
    * registrar('Liberação sem <campo> recusada. Mensagem da API: "' + response.mensagem + '"')

    Examples:
      | campo                   |
      | cpf                     |
      | nascimento_data         |
      | grau_parentesco_id      |
      | tipo_dependencia_id     |
      | inicio_dependencia_data |

  @regressao
  Scenario Outline: Liberação com <caso> é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    * def id = dependente.dependente_id
    Given request <corpo>
    When method post
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()
    * def atual = consultarDependente(s, id)
    And match atual.situacao == 'nao_liberado'

    Examples:
      | caso                                  | corpo                                                                                                              |
      | lista de dependentes vazia            | { empresa_id: '#(s.empresaId)', dependente_id: [], situacao: 'liberado' }                                          |
      | dependente repetido na lista          | { empresa_id: '#(s.empresaId)', dependente_id: ['#(id)', '#(id)'], situacao: 'liberado' }                          |
      | situação inexistente                  | { empresa_id: '#(s.empresaId)', dependente_id: ['#(id)'], situacao: 'situacao_inexistente' }                       |
      | situação ausente                      | { empresa_id: '#(s.empresaId)', dependente_id: ['#(id)'] }                                                         |
      | observação acima de 250 caracteres    | { empresa_id: '#(s.empresaId)', dependente_id: ['#(id)'], situacao: 'liberado', observacao_liberacao: '#(Dados.texto(251))' } |
      | empresa ausente                       | { dependente_id: ['#(id)'], situacao: 'liberado' }                                                                 |

  @regressao
  Scenario: Liberação com a observação no limite de 250 caracteres é aceita

    * def s = usarSessao('parceiro-52')
    * def dependente = criarDependente(s)
    * def observacao = Dados.texto(250)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'liberado', observacao_liberacao: '#(observacao)' }
    When method post
    Then status 200
    * validarContrato()
    * def atual = consultarDependente(s, dependente.dependente_id)
    And match atual.observacao_liberacao == observacao

  @regressao
  Scenario: Liberação de dependente inexistente é rejeitada (400)

    * def s = usarSessao('parceiro-52')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: [999999999], situacao: 'liberado' }
    When method post
    Then status 400
    * validarContrato()

  @regressao @permissoes
  Scenario: Liberação de dependente de outro cliente é rejeitada e a situação é preservada

    * def outro = sessoes['parceiro-19']
    * def dependenteOutroCliente = criarDependente(outro)
    * def s = usarSessao('parceiro-52')
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependenteOutroCliente.dependente_id)'], situacao: 'liberado' }
    When method post
    Then status 400
    * validarContrato()

    Given path '/api/v1/liberacoes/dependentes'
    And request { empresa_id: '#(outraEmpresa(s))', dependente_id: ['#(dependenteOutroCliente.dependente_id)'], situacao: 'liberado' }
    When method post
    Then status 403
    * validarContrato()

    * def atual = consultarDependente(outro, dependenteOutroCliente.dependente_id)
    And match atual.situacao == 'nao_liberado'
    * registrar('Dependente do cliente 19 continuou nao_liberado após tentativas de liberação pela sessão do cliente 52.')

  @regressao @seguranca
  Scenario: Liberação sem token de acesso é rejeitada (401)

    * def s = sessoes['parceiro-52']
    * def dependente = criarDependente(s)
    Given request { empresa_id: '#(s.empresaId)', dependente_id: ['#(dependente.dependente_id)'], situacao: 'liberado' }
    When method post
    Then status 401
    * validarContrato()

  @fluxo
  Scenario Outline: Ciclo completo de integração com o sistema de folha (cliente <cliente>)
    A integração externa cadastra e libera; o sistema de folha consulta os liberados (assumindo a
    integração) e conclui como integrado. Depois disso, a integração externa não pode mais excluir.

    * def parceiro = sessoes['parceiro-<cliente>']
    * def sistema = sessoes['sistema-<cliente>']

    # 1. Integração externa cadastra e libera
    * def dependente = criarDependente(parceiro)
    * definirSituacao(parceiro, dependente.dependente_id, 'liberado')

    # 2. Sistema de folha consulta os liberados: o dependente passa para aguardando_integracao
    * usarSessao('sistema-<cliente>')
    Given path '/api/v1/dependentes'
    And params { empresa_id: '#(sistema.empresaId)', dependente_id: '#(dependente.dependente_id)', situacao: 'liberado' }
    When method get
    Then status 200
    * def atual = consultarDependente(parceiro, dependente.dependente_id)
    And match atual.situacao == 'aguardando_integracao'

    # 3. Sistema de folha conclui a integração
    * definirSituacao(sistema, dependente.dependente_id, 'integrado')
    * def atual = consultarDependente(parceiro, dependente.dependente_id)
    And match atual.situacao == 'integrado'

    # 4. A integração externa não pode mais excluir o dependente integrado
    * usarSessao('parceiro-<cliente>')
    Given path '/api/v1/dependentes'
    And request { empresa_id: '#(parceiro.empresaId)', dependente_id: '#(dependente.dependente_id)' }
    When method delete
    Then status 400
    * registrar('Ciclo concluído para o dependente ' + dependente.dependente_id + ': nao_liberado → liberado → aguardando_integracao → integrado.')

    Examples:
      | cliente |
      | 52      |
      | 19      |
