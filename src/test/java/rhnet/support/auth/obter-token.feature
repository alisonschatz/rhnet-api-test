@ignore
Feature: Obtém o JWT de acesso na API de autenticação
  Chamado uma única vez por execução via karate.callSingle (karate-config.js).
  Basic Auth: usuário = Token de Parceiro, senha = Token de Cliente.

  Scenario:
    * configure headers = null
    * def Auth = Java.type('rhnet.support.auth.Autenticacao')
    Given url authUrl
    And path '/api/v1/auth/credencial/login'
    And header Authorization = 'Basic ' + Auth.basic(parceiroToken, clienteToken)
    When method post
    * if (responseStatus != 201) karate.fail('Login falhou em ' + ambiente + ' com status ' + responseStatus + '. Verifique SCI_PARCEIRO_TOKEN e SCI_CLIENTE_TOKEN deste ambiente.')
    * def token = response.token
