@ignore
Feature: Verificação do ambiente antes dos testes (uso interno)
  Executada uma única vez por execução via karate.callSingle (karate-config.js), antes de
  qualquer teste. Confere a massa de teste e se cada sessão acessa a empresa de teste do seu
  cliente. Se houver problemas, lista todos de uma vez e interrompe a execução.

  Scenario:
    * def escopoSuporte = true
    * def verificar =
      """
      function() {
        var problemas = [].concat(problemasMassa);
        var nomes = Object.keys(sessoes);
        for (var i = 0; i < nomes.length; i++) {
          var s = sessoes[nomes[i]];
          if (!s.empresaId) continue;
          var r = karate.call('classpath:rhnet/support/verificacao/acesso-empresa.feature', { baseUrl: baseUrl, sessao: s });
          if (r.status != 200) {
            problemas.push('Sessão ' + s.nome + ' sem acesso à empresa ' + s.empresaId + ' (status ' + r.status + ')'
              + (r.mensagem ? ': ' + r.mensagem : '') + '. Confira o empresaId do cliente ' + s.cliente + ' e as credenciais.');
          }
        }
        return problemas;
      }
      """
    * def problemas = verificar()
    * if (problemas.length > 0) karate.fail('Ambiente "' + ambiente + '" não está pronto para os testes:\n- ' + problemas.join('\n- '))
