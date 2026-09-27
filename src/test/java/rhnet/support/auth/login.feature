@ignore
Feature: Login de uma sessão na API de autenticação (uso interno)
  Basic Auth: usuário = token de parceiro ou de sistema, senha = token de cliente.

  Scenario:
    * def escopoSuporte = true
    * configure headers = null
    * def Auth = Java.type('rhnet.support.auth.Autenticacao')
    Given url authUrl
    And path '/api/v1/auth/credencial/login'
    And header Authorization = 'Basic ' + Auth.basic(usuario, senha)
    When method post
    * if (responseStatus != 201) karate.fail('Falha ao gerar o token da sessão "' + nome + '" em ' + ambiente + ': status ' + responseStatus + '. Verifique as credenciais dessa sessão.')
    * if (!response.token) karate.fail('Falha ao gerar o token da sessão "' + nome + '": resposta sem o campo "token".')
    * def token = response.token
