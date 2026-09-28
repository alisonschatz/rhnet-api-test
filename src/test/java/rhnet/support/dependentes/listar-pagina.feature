@ignore
Feature: Suporte - lista uma página de dependentes do colaborador de teste (uso interno)
  Argumentos: sessao, pagina. Retorna: dependentes, ultimaPagina.
  Nunca usa o filtro situacao: consultas do sistema de folha com situacao=liberado alteram os registros.

  Scenario:
    * def escopoSuporte = true
    * url baseUrl
    * configure headers = ({ Authorization: 'Bearer ' + sessao.token, Accept: 'application/json' })
    Given path '/api/v1/dependentes'
    And params { empresa_id: '#(sessao.empresaId)', funcionario_contribuinte_id: '#(sessao.funcionarioId)', per_page: 100, page: '#(pagina)' }
    When method get
    * if (responseStatus != 200) karate.fail('Limpeza: falha ao listar dependentes (sessão ' + sessao.nome + ', página ' + pagina + ', status ' + responseStatus + ')')
    * def dependentes = response.retorno
    * def ultimaPagina = response.paginacao && response.paginacao.ultima_pagina ? response.paginacao.ultima_pagina : 1
