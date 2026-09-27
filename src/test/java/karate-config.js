/**
 * Configuração global do Karate. Roda antes de cada cenário.
 *
 *   Ambiente:     -Dkarate.env=hml | prd   (padrão: hml)
 *   URLs:         ambientes.json          Massa de teste: dados-teste.json
 *   Credenciais:  .env.<ambiente> (local) ou variáveis de ambiente (pipeline)
 *
 * Sessões (uma por combinação de tokens, autenticadas uma única vez por execução):
 *   parceiro-52, parceiro-19   token de parceiro   (integração externa)
 *   sistema-52,  sistema-19    token de sistema    (sistema de folha / desktop)
 *
 * Disponível em todas as features:
 *   usarSessao(nome)              autentica as próximas requisições com a sessão e a retorna
 *   sessoes                       todas as sessões: { nome, tipo, cliente, token, empresaId, funcionarioId }
 *   outraEmpresa(sessao)          empresa de OUTRO cliente (para testes de acesso indevido)
 *   validarContrato()             valida a última resposta contra spec/<ambiente>/rhnetsocial.json
 *   registrar(texto)              registra uma verificação em português nos relatórios
 *
 *   Dependentes (dados sintéticos, removidos ao final do cenário pela sessão de sistema):
 *   novoDependente(sessao, extras)            item de cadastro válido para a sessão
 *   criarDependente(sessao, extras)           cadastra e registra para limpeza; retorna o dependente
 *   registrarCriados(lista, sessao)           registra para limpeza dependentes criados no próprio teste
 *   edicaoDependente(dep, sessao, extras)     payload completo de edição (PUT) a partir do dependente
 *   consultarDependente(sessao, id)           dependente atual (ou null)
 *   alterarSituacao(sessao, ids, sit, obs)    chama a liberação e retorna { status, resposta }
 *   definirSituacao(sessao, id, situacao)     pré-condição: muda a situação ou interrompe o teste
 *   prepararSituacao(id, cliente, situacao)   pré-condição: leva à situação pelo caminho real (via liberado)
 *   limparCriados                             usar em: configure afterScenario = limparCriados
 */
function fn() {
  var ambiente = karate.env || 'hml';

  // ---------------------------------------------------------------- URLs
  var urls = karate.read('file:ambientes.json')[ambiente];
  if (!urls) {
    throw 'Ambiente "' + ambiente + '" não existe em ambientes.json';
  }
  if (urls.rhnetUrl === 'PREENCHER' || urls.authUrl === 'PREENCHER') {
    throw 'URLs do ambiente "' + ambiente + '" não configuradas em ambientes.json';
  }

  // ---------------------------------------------------------- credenciais
  // Variáveis de ambiente (pipeline) têm prioridade sobre o arquivo .env.<ambiente> (local)
  var arquivoEnv = {};
  var nomeArquivo = '.env.' + ambiente;
  var File = Java.type('java.io.File');
  if (new File(nomeArquivo).exists()) {
    var linhas = karate.readAsString('file:' + nomeArquivo).split(/\r?\n/);
    for (var i = 0; i < linhas.length; i++) {
      var linha = linhas[i].trim();
      var igual = linha.indexOf('=');
      if (linha === '' || linha.charAt(0) === '#' || igual < 1) continue;
      arquivoEnv[linha.substring(0, igual).trim()] = linha.substring(igual + 1).trim();
    }
  }
  function credencial(nome) {
    var valor = karate.sysenv(nome) || arquivoEnv[nome];
    return valor ? valor : null;
  }

  var DEFINICAO_SESSOES = [
    { nome: 'parceiro-52', tipo: 'parceiro', cliente: '52', usuario: 'SCI_PARCEIRO_TOKEN',   senha: 'SCI_CLIENTE_52_TOKEN' },
    { nome: 'parceiro-19', tipo: 'parceiro', cliente: '19', usuario: 'SCI_PARCEIRO_TOKEN',   senha: 'SCI_CLIENTE_19_TOKEN' },
    { nome: 'sistema-52',  tipo: 'sistema',  cliente: '52', usuario: 'SCI_SISTEMA_52_TOKEN', senha: 'SCI_CLIENTE_52_TOKEN' },
    { nome: 'sistema-19',  tipo: 'sistema',  cliente: '19', usuario: 'SCI_SISTEMA_19_TOKEN', senha: 'SCI_CLIENTE_19_TOKEN' }
  ];
  var faltando = [];
  var logins = [];
  for (var j = 0; j < DEFINICAO_SESSOES.length; j++) {
    var d = DEFINICAO_SESSOES[j];
    var usuario = credencial(d.usuario), senha = credencial(d.senha);
    if (!usuario && faltando.indexOf(d.usuario) < 0) faltando.push(d.usuario);
    if (!senha && faltando.indexOf(d.senha) < 0) faltando.push(d.senha);
    logins.push({ nome: d.nome, usuario: usuario, senha: senha });
  }
  if (faltando.length > 0) {
    throw 'Credenciais de "' + ambiente + '" ausentes: ' + faltando.join(', ') + '. Veja o .env.example';
  }

  var config = { ambiente: ambiente, baseUrl: urls.rhnetUrl, authUrl: urls.authUrl };

  // ---------------------------------------------------------------- HTTP
  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);
  // Sem sessão padrão: cada cenário escolhe a sua com usarSessao(...)
  karate.configure('headers', { Accept: 'application/json' });

  // Mascaramento de dados sensíveis (LGPD) em logs, relatório do Karate e anexos do Allure
  karate.configure('logging', {
    mask: {
      headers: ['Authorization', 'Cookie'],
      jsonPaths: ['$..token', '$..cpf', '$..pis', '$..nis', '$..rg', '$..cnh', '$..ctps',
                  '$..titulo_eleitor', '$..salario', '$..remuneracao', '$..conta', '$..senha'],
      replacement: '***'
    }
  });

  // -------------------------------------------------------------- sessões
  var tokens = karate.callSingle('classpath:rhnet/support/auth/obter-tokens.feature',
    { authUrl: urls.authUrl, ambiente: ambiente, logins: logins }).tokens;
  var Auth = Java.type('rhnet.support.auth.Autenticacao');
  var massa = (karate.read('file:dados-teste.json')[ambiente]) || {};

  function empresasDoToken(token) {
    try {
      var jwt = karate.fromJson(Auth.payloadJwt(token));
      return (jwt.usuario && jwt.usuario.dados && jwt.usuario.dados.empresasVinculadas) || [];
    } catch (e) {
      return [];
    }
  }

  // Empresa de cada cliente: dados-teste.json ou, se vazio, a primeira empresa vinculada no token
  var empresaDoCliente = {};
  for (var k = 0; k < DEFINICAO_SESSOES.length; k++) {
    var dc = DEFINICAO_SESSOES[k];
    var definida = massa[dc.cliente] && massa[dc.cliente].empresaId;
    if (definida) empresaDoCliente[dc.cliente] = definida;
    if (!empresaDoCliente[dc.cliente]) empresaDoCliente[dc.cliente] = empresasDoToken(tokens[dc.nome])[0] || null;
  }

  config.sessoes = {};
  for (var m = 0; m < DEFINICAO_SESSOES.length; m++) {
    var ds = DEFINICAO_SESSOES[m];
    var funcionario = massa[ds.cliente] && massa[ds.cliente].funcionarioContribuinteId;
    config.sessoes[ds.nome] = {
      nome: ds.nome,
      tipo: ds.tipo,
      cliente: ds.cliente,
      token: tokens[ds.nome],
      empresaId: empresaDoCliente[ds.cliente],
      funcionarioId: (funcionario && funcionario !== 'PREENCHER') ? funcionario : null
    };
  }

  config.usarSessao = function (nome) {
    var s = config.sessoes[nome];
    if (!s) karate.fail('Sessão desconhecida: ' + nome);
    if (!s.empresaId) karate.fail('Empresa do cliente ' + s.cliente + ' não identificada: defina empresaId em dados-teste.json (' + ambiente + ')');
    karate.configure('headers', { Authorization: 'Bearer ' + s.token, Accept: 'application/json' });
    return s;
  };

  config.outraEmpresa = function (s) {
    for (var c in empresaDoCliente) {
      if (c !== s.cliente && empresaDoCliente[c] && empresaDoCliente[c] !== s.empresaId) return empresaDoCliente[c];
    }
    karate.fail('Não há empresa de outro cliente para o teste de acesso indevido');
  };

  // ----------------------------------------------------------- relatórios
  config.registrar = function (texto) {
    karate.embed(texto, 'text/plain', 'Verificação');
  };

  // ------------------------------------------------------------- contrato
  var Validador = Java.type('rhnet.support.contrato.ValidadorContrato');
  config.validarContrato = function () {
    var req = karate.prevRequest;
    var status = karate.get('responseStatus');
    var erros = Validador.validate(ambiente, 'rhnetsocial', req.method, req.url, status, karate.get('responseBytes'));
    if (erros) {
      karate.fail('\n' + erros);
    }
    var caminho = String(req.url).replace(/^https?:\/\/[^\/]+/, '').split('?')[0];
    karate.embed('Contrato válido: ' + req.method + ' ' + caminho + ' (status ' + status
      + ') está em conformidade com spec/' + ambiente + '/rhnetsocial.json', 'text/plain', 'Contrato');
  };

  // ---------------------------------------------------------- dependentes
  var Dados = Java.type('rhnet.support.dados.GeradorDados');
  var SUPORTE = 'classpath:rhnet/support/dependentes/';

  config.novoDependente = function (s, extras) {
    if (!s.funcionarioId) {
      karate.fail('Defina funcionarioContribuinteId do cliente ' + s.cliente + ' em dados-teste.json ("' + ambiente
        + '"): colaborador de teste ativo, sem desligamento e já liberado.');
    }
    var item = {
      empresa_id: s.empresaId,
      funcionario_contribuinte_id: s.funcionarioId,
      nome: Dados.nome(),
      cpf: Dados.cpfFormatado(),
      nascimento_data: Dados.diasAPartirDeHoje(-3650),
      inicio_dependencia_data: Dados.hoje(),
      grau_parentesco_id: 3,
      tipo_dependencia_id: 1,
      incapaz: false,
      descricao_dependencia: 'Filho(a) - QA AUTO',
      mes_formacao_ensino_superior: null
    };
    // O sistema de folha é obrigado a informar o código do desktop; as demais origens são proibidas
    if (s.tipo === 'sistema') item.v_dependente_id = Dados.codigoDesktop();
    return karate.merge(item, extras || {});
  };

  // Payload de edição (PUT) com TODOS os campos do dependente atual: a API limpa os campos
  // enviados vazios. O v_dependente_id só é enviado pelo sistema de folha.
  config.edicaoDependente = function (d, s, extras) {
    var p = {
      empresa_id: d.empresa_id,
      dependente_id: d.dependente_id,
      funcionario_contribuinte_id: d.funcionario_contribuinte_id,
      nome: d.nome,
      cpf: d.cpf,
      nascimento_data: d.nascimento_data,
      inicio_dependencia_data: d.inicio_dependencia_data,
      grau_parentesco_id: d.grau_parentesco_id,
      tipo_dependencia_id: d.tipo_dependencia_id,
      incapaz: d.incapaz,
      descricao_dependencia: d.descricao_dependencia,
      mes_formacao_ensino_superior: d.mes_formacao_ensino_superior
    };
    if (s.tipo === 'sistema') p.v_dependente_id = d.v_dependente_id;
    return karate.merge(p, extras || {});
  };

  config.registrarCriados = function (lista, s) {
    var criados = karate.get('criados') || [];
    for (var i = 0; i < lista.length; i++) {
      if (lista[i] && lista[i].dependente_id) criados.push({ id: lista[i].dependente_id, cliente: s.cliente });
    }
    karate.set('criados', criados);
  };

  config.criarDependente = function (s, extras) {
    var r = karate.call(SUPORTE + 'criar.feature', { sessao: s, item: config.novoDependente(s, extras) });
    config.registrarCriados([r.dependente], s);
    return r.dependente;
  };

  config.consultarDependente = function (s, id) {
    return karate.call(SUPORTE + 'consultar.feature', { sessao: s, id: id }).dependente;
  };

  config.alterarSituacao = function (s, ids, situacao, observacao) {
    var r = karate.call(SUPORTE + 'liberar.feature',
      { sessao: s, ids: ids, situacao: situacao, observacao: observacao || null });
    return { status: r.status, resposta: r.resposta };
  };

  config.definirSituacao = function (s, id, situacao) {
    var r = config.alterarSituacao(s, [id], situacao, null);
    if (r.status !== 200) {
      karate.fail('Pré-condição: não foi possível definir a situação "' + situacao + '" do dependente ' + id
        + ' com a sessão ' + s.nome + ' (status ' + r.status + '): ' + JSON.stringify(r.resposta));
    }
  };

  // Pré-condição: leva o dependente até a situação desejada pelo caminho real do processo
  // (nao_liberado → liberado → situação do sistema de folha), usando a sessão de sistema do cliente.
  config.prepararSituacao = function (id, cliente, situacao) {
    if (situacao === 'nao_liberado') return;
    var sistema = config.sessoes['sistema-' + cliente];
    config.definirSituacao(sistema, id, 'liberado');
    if (situacao !== 'liberado') config.definirSituacao(sistema, id, situacao);
  };

  // Remove, ao final do cenário, tudo o que o teste criou. Usa a sessão de SISTEMA do cliente,
  // a única que pode excluir dependentes em qualquer situação. Ignorado dentro das features de suporte.
  config.limparCriados = function () {
    if (karate.get('escopoSuporte')) return;
    var criados = karate.get('criados') || [];
    for (var i = 0; i < criados.length; i++) {
      karate.call(SUPORTE + 'remover.feature', { sessao: config.sessoes['sistema-' + criados[i].cliente], id: criados[i].id });
    }
  };

  return config;
}
