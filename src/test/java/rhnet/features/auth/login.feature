@auth
Feature: API de autenticação - POST /api/v1/auth/credencial/login
  Basic Auth: usuário = Token de Parceiro, senha = Token de Cliente.
  Sucesso retorna 201 com { mensagem, token (JWT), validade: 3600 }.

  Background:
    * url authUrl
    * path '/api/v1/auth/credencial/login'
    * configure headers = null
    * def Auth = Java.type('rhnet.support.auth.Autenticacao')

  @smoke
  Scenario: Credenciais válidas geram JWT com validade de 1 hora
    Given header Authorization = 'Basic ' + Auth.basic(parceiroToken, clienteToken)
    When method post
    Then status 201
    # O token nunca aparece em mensagens de erro: é validado à parte e mascarado na comparação
    * assert response.token != null && /^[^.]+[.][^.]+[.][^.]+$/.test(response.token)
    * def respostaMascarada = karate.merge(response, { token: '***' })
    And match respostaMascarada == { mensagem: '#string', token: '***', validade: 3600 }
    * validarContrato('auth')

  Scenario: Token de cliente inválido retorna 401
    Given header Authorization = 'Basic ' + Auth.basic(parceiroToken, 'cliente-invalido')
    When method post
    Then status 401
    And match response.mensagem contains 'Credenciais inválidas'
    * validarContrato('auth')

  Scenario: Token de parceiro inválido retorna 401
    Given header Authorization = 'Basic ' + Auth.basic('parceiro-invalido', clienteToken)
    When method post
    Then status 401
    And match response.mensagem contains 'Credenciais inválidas'
    * validarContrato('auth')
