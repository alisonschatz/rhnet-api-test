@ignore
Feature: MODELO - remoção tolerante a falhas (teardown)

  Scenario:
    Given url baseUrl
    And path '/api/v1/RECURSO', id
    When method delete
    * if (responseStatus >= 400) karate.log('Limpeza: registro', id, 'não removido. Status', responseStatus)
