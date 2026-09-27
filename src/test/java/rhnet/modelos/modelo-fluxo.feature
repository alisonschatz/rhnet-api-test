@ignore
Feature: MODELO - Ciclo de vida de RECURSO
  Criar -> consultar -> atualizar -> remover, com limpeza garantida.
  Exemplo completo e real (com utilitários de criação e limpeza): features/dependentes/.
  Copie para features/<área>/, troque os marcadores, remova o @ignore e use a tag @fluxo.
  Roda em hml e prd, sempre com as contas de teste do ambiente.

  Background:
    * url baseUrl
    * def Dados = Java.type('rhnet.support.dados.GeradorDados')
    * def criados = []
    # Limpeza executada sempre ao final, mesmo se o cenário falhar no meio
    * configure afterScenario =
      """
      function() {
        var ids = karate.get('criados');
        for (var i = 0; i < ids.length; i++) {
          karate.call('classpath:rhnet/modelos/modelo-remover.feature', { id: ids[i] });
        }
      }
      """

  @fluxo
  Scenario: RECURSO pode ser criado, consultado, atualizado e removido
    Verifica o ciclo completo de um registro criado com dados sintéticos (prefixo QA AUTO).
    O registro é removido ao final, inclusive em caso de falha.

    * def s = usarSessao('parceiro-52')

    # Criação
    * def payload = { nome: '#(Dados.nome())', documento: '#(Dados.cpf())' }
    Given path '/api/v1/RECURSO'
    And request payload
    When method post
    # Registra para limpeza antes de qualquer verificação
    * if (responseStatus < 300) karate.appendTo('criados', response.CAMPO_ID)
    Then status 201
    * def id = response.CAMPO_ID
    * registrar('Registro criado: CAMPO_ID = ' + id + ', nome = "' + payload.nome + '".')
    * validarContrato()

    # Consulta
    Given path '/api/v1/RECURSO', id
    When method get
    Then status 200
    And match response contains { nome: '#(payload.nome)' }
    * registrar('Consulta confirmou os dados gravados.')

    # Atualização
    * def novoNome = Dados.nome()
    Given path '/api/v1/RECURSO', id
    And request { nome: '#(novoNome)' }
    When method put
    Then status 200
    * registrar('Registro atualizado: nome = "' + novoNome + '".')
    * validarContrato()

    # Remoção
    * call read('classpath:rhnet/modelos/modelo-remover.feature') { id: '#(id)' }
    * karate.set('criados', [])
    Given path '/api/v1/RECURSO', id
    When method get
    Then status 404
    * registrar('Registro removido: a consulta após a remoção retornou 404.')
