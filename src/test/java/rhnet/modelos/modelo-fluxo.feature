@ignore
Feature: MODELO - ciclo de vida com criação de dados (copie para features/fluxos/)
  Criar -> consultar -> atualizar -> remover, com limpeza garantida.
  Remova o @ignore na cópia e use a tag @fluxo.
  Roda em hml e prd, sempre com as contas de teste do ambiente.

  Background:
    * url baseUrl
    * def Dados = Java.type('rhnet.support.dados.GeradorDados')
    * def criados = []
    # Limpeza roda SEMPRE, mesmo se o cenário falhar no meio
    * configure afterScenario =
      """
      function() {
        var ids = karate.get('criados');
        for (var i = 0; i < ids.length; i++) {
          karate.call('classpath:rhnet/modelos/modelo-remover.feature', { id: ids[i] });
        }
      }
      """

  Scenario: Criar, consultar, atualizar e remover RECURSO
    * def payload = { nome: '#(Dados.nome())', documento: '#(Dados.cpf())' }
    Given path '/api/v1/RECURSO'
    And request payload
    When method post
    # Registra para limpeza ANTES de qualquer assert
    * if (responseStatus < 300) karate.appendTo('criados', response.CAMPO_ID)
    Then status 201
    * validarContrato()
    * def id = response.CAMPO_ID

    Given path '/api/v1/RECURSO', id
    When method get
    Then status 200
    And match response contains { nome: '#(payload.nome)' }

    * def novoNome = Dados.nome()
    Given path '/api/v1/RECURSO', id
    And request { nome: '#(novoNome)' }
    When method put
    Then status 200
    * validarContrato()

    * call read('classpath:rhnet/modelos/modelo-remover.feature') { id: '#(id)' }
    * karate.set('criados', [])
    Given path '/api/v1/RECURSO', id
    When method get
    Then status 404
