@ignore
Feature: Verificação - acesso de uma sessão à empresa de teste do seu cliente (uso interno)
  Argumentos: sessao. Retorna: status, mensagem. Consulta somente leitura, sem filtro de situação.

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/dependentes'
    And params { empresa_id: '#(sessao.empresaId)', per_page: 1 }
    When method get
    * def status = responseStatus
    * def mensagem = response && (response.mensagem || response.message) ? (response.mensagem || response.message) : ''
