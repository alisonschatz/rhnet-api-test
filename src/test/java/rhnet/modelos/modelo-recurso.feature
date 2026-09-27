@ignore
Feature: MODELO - Nome do recurso - GET /api/v1/RECURSO
  Copie para features/<área>/<recurso>.feature, troque os marcadores (RECURSO, CAMPO_*)
  pelos nomes reais da spec e remova o @ignore.

  Padrão de escrita (é o que aparece no relatório):
  - Título do cenário: o que é feito -> o que se espera. Ex.: "Consulta sem X é rejeitada (400)".
  - Descrição logo abaixo do título: a regra de negócio verificada, em uma ou duas frases.
  - karate.log(...) nos pontos-chave: o que foi confirmado, com os valores reais.
  - validarContrato() após cada resposta.

  Background:
    * url baseUrl
    * path '/api/v1/RECURSO'

  @smoke
  Scenario: Consulta de RECURSO retorna a lista com sucesso
    Com os parâmetros obrigatórios válidos, a API deve responder 200 com a lista no envelope padrão.

    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.retorno == '#array'
    * karate.log('Consulta retornou ' + response.retorno.length + ' registro(s).')
    * validarContrato()

  @regressao
  Scenario: Consulta sem CAMPO_OBRIGATORIO é rejeitada com erro de validação (400)
    O CAMPO_OBRIGATORIO é obrigatório. A API deve recusar a consulta e indicar
    o campo faltante em "erros.CAMPO_OBRIGATORIO".

    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.CAMPO_OBRIGATORIO == '#[_ > 0] #string'
    * karate.log('Consulta rejeitada como esperado. Mensagem da API: "' + response.erros.CAMPO_OBRIGATORIO[0] + '"')
    * validarContrato()

  @regressao
  Scenario: Filtro por CAMPO_ID retorna apenas o registro solicitado
    Nunca use IDs fixos: o teste busca um registro existente no ambiente e filtra por ele.

    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 200
    * if (response.retorno.length == 0) karate.abort()
    * def id = response.retorno[0].CAMPO_ID

    Given path '/api/v1/RECURSO'
    And params { sistema_id: '#(sessao.sistemaId)', CAMPO_ID: '#(id)' }
    When method get
    Then status 200
    And match each response.retorno contains { CAMPO_ID: '#(id)' }
    * karate.log('Filtro por CAMPO_ID = ' + id + ' retornou apenas o registro solicitado.')
    * validarContrato()
