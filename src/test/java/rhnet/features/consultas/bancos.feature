@consultas
Feature: Bancos - GET /api/v1/bancos
  Parâmetros: sistema_id (obrigatório), banco_id e alterado_data (opcionais).
  alterado_data usa o formato AAAA-MM-DD HH:MM:SS.

  Background:
    * url baseUrl
    * path '/api/v1/bancos'

  @smoke
  Scenario: Lista bancos
    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.retorno == '#array'
    * validarContrato()

  @regressao
  Scenario: Sem sistema_id retorna 400
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.sistema_id == '#[_ > 0] #string'
    * validarContrato()

  @regressao
  Scenario: alterado_data no futuro não retorna registros
    Given params { sistema_id: '#(sessao.sistemaId)', alterado_data: '2099-12-31 23:59:59' }
    When method get
    Then status 200
    And match response.retorno == []
    * validarContrato()

  @regressao
  Scenario: alterado_data fora do formato AAAA-MM-DD HH:MM:SS retorna 400
    Given params { sistema_id: '#(sessao.sistemaId)', alterado_data: '31/12/2024' }
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * validarContrato()

  @regressao
  Scenario: Sem token retorna 401
    * configure headers = { Accept: 'application/json' }
    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 401
    And match response.mensagem == '#string'
    * validarContrato()
