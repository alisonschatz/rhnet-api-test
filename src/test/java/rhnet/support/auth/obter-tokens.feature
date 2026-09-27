@ignore
Feature: Gera o token de todas as sessões de teste (uso interno)
  Etapa de preparação, não é um teste: executada uma única vez por execução via
  karate.callSingle (karate-config.js). Se qualquer sessão falhar, a execução é interrompida.

  Scenario:
    * def escopoSuporte = true
    * def logar =
      """
      function() {
        var tokens = {};
        for (var i = 0; i < logins.length; i++) {
          var l = logins[i];
          var r = karate.call('classpath:rhnet/support/auth/login.feature',
            { authUrl: authUrl, ambiente: ambiente, nome: l.nome, usuario: l.usuario, senha: l.senha });
          tokens[l.nome] = r.token;
        }
        return tokens;
      }
      """
    * def tokens = logar()
