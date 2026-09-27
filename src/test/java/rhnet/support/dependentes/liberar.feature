@ignore
Feature: Suporte - altera a situação de liberação de dependentes (uso interno)
  Argumentos: sessao, ids, situacao, observacao. Retorna: status, resposta (sem verificar o resultado).

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/liberacoes/dependentes'
    And request { empresa_id: '#(sessao.empresaId)', dependente_id: '#(ids)', situacao: '#(situacao)', observacao_liberacao: '#(observacao)' }
    When method post
    * def status = responseStatus
    * def resposta = response
