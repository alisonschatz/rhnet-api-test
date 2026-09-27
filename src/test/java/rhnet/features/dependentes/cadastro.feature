@dependentes
Feature: Dependentes - cadastro (POST /api/v1/dependentes)
  Cadastra um ou mais dependentes (array "dados"). Todo dependente nasce com a situação nao_liberado.
  O v_dependente_id é obrigatório para o sistema de folha e proibido para as demais origens.
  O colaborador precisa estar ativo e sem desligamento; a inicio_dependencia_data não pode cair
  em competência bloqueada.

  Background:
    * url baseUrl
    * path '/api/v1/dependentes'
    * def criados = []
    * configure afterScenario = limparCriados
    * def Dados = Java.type('rhnet.support.dados.GeradorDados')
    * def digitos = function(v) { return v ? v.replace(/\D/g, '') : v }

  @smoke
  Scenario Outline: Cadastro completo é aceito e nasce não liberado (<sessao>)
    Todos os campos preenchidos. O dependente é gravado com os dados enviados e a situação nao_liberado.

    * def s = usarSessao('<sessao>')
    * def item = novoDependente(s)
    Given request { dados: ['#(item)'] }
    When method post
    Then status 201
    * registrarCriados(response.retorno, s)
    And match response contains { sucesso: true, status: 201 }
    And match response.retorno == '#[1]'
    * def gravado = response.retorno[0]
    And match gravado contains
      """
      {
        dependente_id: '#number',
        empresa_id: '#(item.empresa_id)',
        funcionario_contribuinte_id: '#(item.funcionario_contribuinte_id)',
        nome: '#(item.nome)',
        nascimento_data: '#(item.nascimento_data)',
        inicio_dependencia_data: '#(item.inicio_dependencia_data)',
        grau_parentesco_id: 3,
        tipo_dependencia_id: 1,
        situacao: 'nao_liberado'
      }
      """
    * def cpfGravado = digitos(gravado.cpf)
    And match cpfGravado == digitos(item.cpf)
    * registrar('Dependente ' + gravado.dependente_id + ' cadastrado por ' + s.nome + ' com a situação nao_liberado.')
    * validarContrato()

    Examples:
      | sessao      |
      | parceiro-52 |
      | parceiro-19 |
      | sistema-52  |
      | sistema-19  |

  @regressao
  Scenario Outline: Cadastro só com os campos obrigatórios é aceito (<sessao>)
    Obrigatórios: empresa_id, funcionario_contribuinte_id e nome (e v_dependente_id para o sistema de folha).

    * def s = usarSessao('<sessao>')
    * def completo = novoDependente(s)
    * def item = { empresa_id: '#(completo.empresa_id)', funcionario_contribuinte_id: '#(completo.funcionario_contribuinte_id)', nome: '#(completo.nome)' }
    * if (s.tipo == 'sistema') karate.set('item', karate.merge(item, { v_dependente_id: completo.v_dependente_id }))
    Given request { dados: ['#(item)'] }
    When method post
    Then status 201
    * registrarCriados(response.retorno, s)
    And match response.retorno[0] contains { nome: '#(item.nome)', situacao: 'nao_liberado' }
    * registrar('Cadastro mínimo aceito para ' + s.nome + ': dependente ' + response.retorno[0].dependente_id + '.')
    * validarContrato()

    Examples:
      | sessao      |
      | parceiro-52 |
      | sistema-52  |

  @regressao
  Scenario: Cadastro em lote grava todos os dependentes enviados

    * def s = usarSessao('parceiro-52')
    * def primeiro = novoDependente(s)
    * def segundo = novoDependente(s)
    Given request { dados: ['#(primeiro)', '#(segundo)'] }
    When method post
    Then status 201
    * registrarCriados(response.retorno, s)
    And match response.retorno == '#[2]'
    And match response.retorno[*].nome contains only [ '#(primeiro.nome)', '#(segundo.nome)' ]
    And assert response.retorno[0].dependente_id != response.retorno[1].dependente_id
    * registrar('Lote com 2 dependentes cadastrado: IDs ' + response.retorno[0].dependente_id + ' e ' + response.retorno[1].dependente_id + '.')
    * validarContrato()

  @regressao @permissoes
  Scenario Outline: Integração externa não pode informar o v_dependente_id (cliente <cliente>)
    O código do sistema de folha é proibido fora do sistema de folha.

    * def s = usarSessao('parceiro-<cliente>')
    * def item = novoDependente(s, { v_dependente_id: Dados.codigoDesktop() })
    Given request { dados: ['#(item)'] }
    When method post
    * if (responseStatus == 201) registrarCriados(response.retorno, s)
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * registrar('Cadastro com v_dependente_id rejeitado para ' + s.nome + '. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao @permissoes
  Scenario Outline: Sistema de folha precisa informar o v_dependente_id (cliente <cliente>)

    * def s = usarSessao('sistema-<cliente>')
    * def item = novoDependente(s)
    * remove item.v_dependente_id
    Given request { dados: ['#(item)'] }
    When method post
    * if (responseStatus == 201) registrarCriados(response.retorno, s)
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * registrar('Cadastro sem v_dependente_id rejeitado para ' + s.nome + '. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()

    Examples:
      | cliente |
      | 52      |
      | 19      |

  @regressao
  Scenario: A situação não pode ser definida no cadastro
    Todo dependente nasce nao_liberado: uma situação enviada no cadastro é recusada (400)
    ou ignorada. Em nenhum caso o dependente pode nascer liberado.

    * def s = usarSessao('parceiro-52')
    * def item = novoDependente(s, { situacao: 'liberado' })
    Given request { dados: ['#(item)'] }
    When method post
    * if (responseStatus == 201) registrarCriados(response.retorno, s)
    Then assert responseStatus == 400 || response.retorno[0].situacao == 'nao_liberado'
    * registrar(responseStatus == 400 ? 'Situação enviada no cadastro foi recusada (400).' : 'Situação enviada foi ignorada: o dependente nasceu nao_liberado.')
    * validarContrato()

  @regressao
  Scenario Outline: Cadastro sem o campo obrigatório <campo> é rejeitado (400)

    * def s = usarSessao('parceiro-52')
    * def item = novoDependente(s)
    * remove item.<campo>
    Given request { dados: ['#(item)'] }
    When method post
    * if (responseStatus == 201) registrarCriados(response.retorno, s)
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros['dados.0.<campo>'] == '#[_ > 0] #string'
    * registrar('Mensagem da API: "' + response.erros['dados.0.<campo>'][0] + '"')
    * validarContrato()

    Examples:
      | campo                       |
      | empresa_id                  |
      | funcionario_contribuinte_id |
      | nome                        |

  @regressao
  Scenario Outline: Cadastro com <caso> é rejeitado (400)

    * def s = usarSessao('parceiro-52')
    * def item = novoDependente(s, <alteracao>)
    Given request { dados: ['#(item)'] }
    When method post
    * if (responseStatus == 201) registrarCriados(response.retorno, s)
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * registrar('Cadastro com ' + '<caso>' + ' rejeitado. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()

    Examples:
      | caso                                          | alteracao                                          |
      | nascimento_data inexistente                   | { nascimento_data: '2020-13-45' }                  |
      | inicio_dependencia_data fora do formato       | { inicio_dependencia_data: '31/12/2024' }          |
      | grau_parentesco_id fora da lista (10)         | { grau_parentesco_id: 10 }                         |
      | tipo_dependencia_id fora da lista (8)         | { tipo_dependencia_id: 8 }                         |
      | nome acima de 255 caracteres                  | { nome: Dados.texto(256) }                         |
      | descricao_dependencia acima de 100 caracteres | { descricao_dependencia: Dados.texto(101) }        |
      | funcionario_contribuinte_id inexistente       | { funcionario_contribuinte_id: 999999999 }         |
      | empresa_id como texto                         | { empresa_id: 'abc' }                              |

  @regressao
  Scenario Outline: Cadastro com o limite exato de <campo> é aceito

    * def s = usarSessao('parceiro-52')
    * def item = novoDependente(s, { <campo>: Dados.texto(<tamanho>) })
    Given request { dados: ['#(item)'] }
    When method post
    Then status 201
    * registrarCriados(response.retorno, s)
    And match response.retorno[0].<campo> == item.<campo>
    * validarContrato()

    Examples:
      | campo                 | tamanho |
      | nome                  | 255     |
      | descricao_dependencia | 100     |

  @regressao
  Scenario Outline: Cadastro com a lista de dependentes <caso> é rejeitado (400)

    * usarSessao('parceiro-52')
    Given request <corpo>
    When method post
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()

    Examples:
      | caso    | corpo                  |
      | vazia   | { dados: [] }          |
      | ausente | { }                    |
      | inválida | { dados: 'nao-lista' } |

  @regressao @permissoes
  Scenario Outline: Cadastro na empresa de outro cliente é negado (<sessao>)

    * def s = usarSessao('<sessao>')
    * def item = novoDependente(s, { empresa_id: outraEmpresa(s) })
    Given request { dados: ['#(item)'] }
    When method post
    Then status 403
    And match response contains { sucesso: false, status: 403 }
    * registrar('Cadastro em empresa de outro cliente negado para ' + s.nome + '.')
    * validarContrato()

    Examples:
      | sessao      |
      | parceiro-52 |
      | sistema-19  |

  @regressao @seguranca
  Scenario: Cadastro sem token de acesso é rejeitado (401)

    * def item = novoDependente(sessoes['parceiro-52'])
    Given request { dados: ['#(item)'] }
    When method post
    Then status 401
    And match response.mensagem == '#string'
    * validarContrato()
