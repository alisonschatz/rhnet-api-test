@ignore
Feature: Suporte - remove um dependente criado pelos testes (limpeza, uso interno)
  Argumentos: sessao (de sistema, que exclui em qualquer situação), id.
  Tolerante a falhas: se o registro já não existir, apenas registra no log.

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/dependentes'
    And request { empresa_id: '#(sessao.empresaId)', dependente_id: '#(id)' }
    When method delete
    * if (responseStatus == 200) karate.log('Limpeza: dependente ' + id + ' removido.')
    * if (responseStatus != 200) karate.log('Limpeza: dependente ' + id + ' não removido (status ' + responseStatus + ').')
