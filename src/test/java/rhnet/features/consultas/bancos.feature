@consultas
Feature: Bancos - GET /api/v1/bancos
  Consulta dos bancos cadastrados, usada no cadastro de dados bancários dos colaboradores.
  Parâmetros: sistema_id (obrigatório), banco_id e alterado_data (opcionais).
  O parâmetro alterado_data usa o formato AAAA-MM-DD HH:MM:SS.

  Background:
    * url baseUrl
    * path '/api/v1/bancos'

  @smoke
  Scenario: Consulta de bancos do sistema retorna a lista com sucesso
    Com um sistema_id válido, a API deve responder 200 com a lista de bancos
    no envelope padrão (sucesso, status, mensagem, paginacao, retorno).

    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 200
    And match response contains { sucesso: true, status: 200 }
    And match response.retorno == '#array'
    * karate.log('Consulta retornou ' + response.retorno.length + ' banco(s) para o sistema ' + sessao.sistemaId + '.')
    * validarContrato()

  @regressao
  Scenario: Consulta sem sistema_id é rejeitada com erro de validação (400)
    O sistema_id é obrigatório. A API deve recusar a consulta e indicar
    o campo faltante em "erros.sistema_id".

    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    And match response.erros.sistema_id == '#[_ > 0] #string'
    * karate.log('Consulta rejeitada como esperado. Mensagem da API: "' + response.erros.sistema_id[0] + '"')
    * validarContrato()

  @regressao
  Scenario: Consulta com alterado_data no futuro não retorna registros
    O filtro alterado_data retorna apenas bancos alterados a partir da data informada.
    Com uma data futura, nenhum banco pode atender ao filtro e a lista deve vir vazia.

    Given params { sistema_id: '#(sessao.sistemaId)', alterado_data: '2099-12-31 23:59:59' }
    When method get
    Then status 200
    And match response.retorno == []
    * karate.log('Filtro com data futura (2099-12-31 23:59:59) retornou lista vazia, como esperado.')
    * validarContrato()

  @regressao
  Scenario: Consulta com alterado_data em formato inválido é rejeitada (400)
    O alterado_data deve seguir o formato AAAA-MM-DD HH:MM:SS.
    Uma data em outro formato (31/12/2024) deve ser recusada com erro de validação.

    Given params { sistema_id: '#(sessao.sistemaId)', alterado_data: '31/12/2024' }
    When method get
    Then status 400
    And match response contains { sucesso: false, status: 400 }
    * karate.log('Data em formato inválido (31/12/2024) rejeitada como esperado. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()

  @regressao
  Scenario: Consulta sem token de acesso é rejeitada (401)
    Todo endpoint da RH NET Social exige autenticação. Sem o cabeçalho
    Authorization, a API deve recusar a consulta com 401.

    * configure headers = { Accept: 'application/json' }
    Given param sistema_id = sessao.sistemaId
    When method get
    Then status 401
    And match response.mensagem == '#string'
    * karate.log('Consulta sem token rejeitada como esperado. Mensagem da API: "' + response.mensagem + '"')
    * validarContrato()
