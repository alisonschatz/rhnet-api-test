@ignore
Feature: Suporte - consulta um dependente pelo ID (uso interno)
  Argumentos: sessao, id. Retorna: dependente (null se não encontrado).
  Nunca usa o filtro situacao: consultas do sistema de folha com situacao=liberado alteram os registros.

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/dependentes'
    And params { empresa_id: '#(sessao.empresaId)', dependente_id: '#(id)' }
    When method get
    * if (responseStatus != 200) karate.fail('Consulta do dependente ' + id + ' falhou (sessão ' + sessao.nome + ', status ' + responseStatus + ')')
    * def dependente = response.retorno.length > 0 ? response.retorno[0] : null
