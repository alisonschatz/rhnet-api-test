@ignore
Feature: Suporte - cadastra um dependente como pré-condição (uso interno)
  Argumentos: sessao, item. Retorna: dependente. Interrompe o teste se o cadastro falhar.

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/dependentes'
    And request { dados: ['#(item)'] }
    When method post
    * if (responseStatus != 201) karate.fail('Pré-condição: cadastro de dependente falhou (sessão ' + sessao.nome + ', status ' + responseStatus + '): ' + JSON.stringify(response))
    * def dependente = response.retorno[0]
