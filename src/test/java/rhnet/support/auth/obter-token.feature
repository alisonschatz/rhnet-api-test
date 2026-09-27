@ignore
Feature: Obtém o JWT de acesso na API de autenticação
  Etapa de preparação, não é um teste: executada uma única vez por execução via
  karate.callSingle (karate-config.js). Se o token não for gerado, a execução é interrompida.
  Basic Auth: usuário = Token de Parceiro, senha = Token de Cliente.

  Scenario:
    * configure headers = null
    * def Auth = Java.type('rhnet.support.auth.Autenticacao')
    Given url authUrl
    And path '/api/v1/auth/credencial/login'
    And header Authorization = 'Basic ' + Auth.basic(parceiroToken, clienteToken)
    When method post
    * if (responseStatus != 201) karate.fail('Falha ao gerar o token em ' + ambiente + ': status ' + responseStatus + '. Verifique SCI_PARCEIRO_TOKEN e SCI_CLIENTE_TOKEN deste ambiente.')
    * if (!response.token) karate.fail('Falha ao gerar o token em ' + ambiente + ': resposta sem o campo "token".')
    * def token = response.token
