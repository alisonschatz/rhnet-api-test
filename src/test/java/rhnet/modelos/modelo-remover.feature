@ignore
Feature: MODELO - Remoção de RECURSO (limpeza)
  Chamada pelo afterScenario do modelo de fluxo. Tolerante a falhas: se o registro
  já não existir, apenas registra no relatório.

  Scenario:
    * def escopoSuporte = true
    Given url baseUrl
    And path '/api/v1/RECURSO', id
    When method delete
    * if (responseStatus < 400) karate.log('Limpeza: registro ' + id + ' removido.')
    * if (responseStatus >= 400) karate.log('Limpeza: registro ' + id + ' não foi removido (status ' + responseStatus + ').')
