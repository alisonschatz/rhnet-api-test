@consultas
Feature: Cadastros básicos - listagens por empresa
  Consultas de apoio da folha. Exigem sistema_id e empresa_id, ambos obtidos da sessão
  do usuário de teste (empresa_id = primeira empresa vinculada).
  Para cobrir outra listagem com o mesmo comportamento, basta adicionar uma linha às tabelas.

  Background:
    * url baseUrl
    * def empresaId = sessao.usuario.dados.empresasVinculadas[0]

  @smoke
  Scenario Outline: Lista <recurso> da empresa
    Given path '<endpoint>'
    And params { sistema_id: '#(sessao.sistemaId)', empresa_id: '#(empresaId)' }
    When method get
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.retorno == '#array'
    * validarContrato()

    Examples:
      | recurso          | endpoint                |
      | funções          | /api/v1/funcoes         |
      | departamentos    | /api/v1/departamentos   |
      | centros de custo | /api/v1/centros-custo   |
      | sindicatos       | /api/v1/sindicatos      |

  @regressao
  Scenario Outline: Lista <recurso> sem empresa_id retorna 400
    Given path '<endpoint>'
    And param sistema_id = sessao.sistemaId
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.empresa_id == '#[_ > 0] #string'
    * validarContrato()

    Examples:
      | recurso          | endpoint                |
      | funções          | /api/v1/funcoes         |
      | departamentos    | /api/v1/departamentos   |
      | centros de custo | /api/v1/centros-custo   |
      | sindicatos       | /api/v1/sindicatos      |
