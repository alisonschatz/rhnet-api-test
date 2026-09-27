@ignore
Feature: MODELO - regras de um recurso (copie para features/<area>/<recurso>.feature)
  Escreva a partir do swagger interno e das regras combinadas com o dev/PO,
  nunca da documentação do cliente. Remova o @ignore na cópia.

  Background:
    * url baseUrl

  Scenario: Parâmetro obrigatório ausente retorna 400
    Given path '/api/v1/RECURSO'
    When method get
    Then status 400
    * validarContrato()

  Scenario: Filtro por ID retorna apenas o registro solicitado
    # Nunca fixe IDs: busque um registro existente em HML e use o ID dele
    Given path '/api/v1/RECURSO'
    When method get
    Then status 200
    * if (karate.sizeOf(response.CAMPO_LISTA) == 0) karate.abort()
    * def id = response.CAMPO_LISTA[0].CAMPO_ID

    Given path '/api/v1/RECURSO'
    And param CAMPO_ID = id
    When method get
    Then status 200
    And match each response.CAMPO_LISTA contains { CAMPO_ID: '#(id)' }

  Scenario Outline: Valor inválido em <campo> retorna 400
    Given path '/api/v1/RECURSO'
    And param <campo> = '<valor>'
    When method get
    Then status 400

    Examples:
      | campo    | valor        |
      | CAMPO_A  | texto        |
      | CAMPO_B  | 31/12/2024   |
