@limpeza
Feature: Manutenção - limpeza de dados de teste órfãos
  Remove dependentes de teste que ficaram para trás, por exemplo quando uma execução foi
  interrompida antes da limpeza automática. Por segurança, só remove dependentes que atendem
  às DUAS condições: pertencem ao colaborador de teste (dados-teste.json) e têm o nome com o
  prefixo "QA AUTO". Usa a sessão de sistema, que exclui em qualquer situação.

  Não roda junto com os testes: execute com ".\rodar <ambiente> limpeza". No pipeline, roda
  automaticamente ao final de cada execução.

  Scenario Outline: Remove os dependentes de teste órfãos do cliente <cliente>

    * def sistema = usarSessao('sistema-<cliente>')
    * def prefixo = Java.type('rhnet.support.dados.GeradorDados').PREFIXO
    * def buscarOrfaos =
      """
      function() {
        var orfaos = [];
        var pagina = 1, ultima = 1;
        while (pagina <= ultima) {
          var r = karate.call('classpath:rhnet/support/dependentes/listar-pagina.feature', { sessao: sistema, pagina: pagina });
          for (var i = 0; i < r.dependentes.length; i++) {
            var d = r.dependentes[i];
            if (d.nome && d.nome.indexOf(prefixo) === 0) orfaos.push(d.dependente_id);
          }
          ultima = r.ultimaPagina;
          pagina++;
        }
        return orfaos;
      }
      """
    * def orfaos = buscarOrfaos()
    * def remover =
      """
      function(ids) {
        for (var i = 0; i < ids.length; i++) {
          karate.call('classpath:rhnet/support/dependentes/remover.feature', { sessao: sistema, id: ids[i] });
        }
      }
      """
    * remover(orfaos)
    * def restantes = buscarOrfaos()
    And match restantes == []
    * def texto = 'Cliente <cliente>: ' + orfaos.length + ' dependente(s) de teste órfão(s) removido(s) da empresa ' + sistema.empresaId + '.'
    * registrar(texto)
    * def FileWriter = Java.type('java.io.FileWriter')
    * def saida = new FileWriter('target/limpeza.txt', true)
    * saida.write(texto + '\n')
    * saida.close()

    Examples:
      | cliente |
      | 52      |
      | 19      |
