/**
 * Configuração global do Karate. Roda antes de cada cenário.
 *
 *   Ambiente:     -Dkarate.env=hml | prd   (padrão: hml)
 *   URLs:         ambientes.json (raiz do projeto)
 *   Credenciais:  .env.<ambiente> (local) ou variáveis de ambiente (pipeline)
 *
 * Disponível em todas as features:
 *   baseUrl, authUrl       URLs da RH NET Social e da API de auth
 *   ambiente               hml | prd
 *   token                  JWT do usuário de teste (gerado uma vez por execução)
 *   sessao                 dados do JWT: sessao.sistemaId, sessao.usuario.dados.empresasVinculadas...
 *   validarContrato()      valida a última resposta contra spec/<ambiente>/rhnetsocial.json
 *   registrar(texto)       registra uma verificação em português nos relatórios (Karate e Allure)
 */
function fn() {
  var ambiente = karate.env || 'hml';

  // ---------------------------------------------------------------- URLs
  var ambientes = karate.read('file:ambientes.json');
  var urls = ambientes[ambiente];
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

  var config = {
    ambiente: ambiente,
    baseUrl: urls.rhnetUrl,
    authUrl: urls.authUrl,
    parceiroToken: credencial('SCI_PARCEIRO_TOKEN'),
    clienteToken: credencial('SCI_CLIENTE_TOKEN')
  };
  if (!config.parceiroToken || !config.clienteToken) {
    throw 'Credenciais de "' + ambiente + '" não encontradas. Crie o arquivo .env.' + ambiente + ' a partir do .env.example';
  }

  // ---------------------------------------------------------------- HTTP
  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 30000);

  // Mascaramento de dados sensíveis (LGPD) em logs, relatório do Karate e anexos do Allure
  karate.configure('logging', {
    mask: {
      headers: ['Authorization', 'Cookie'],
      jsonPaths: ['$..token', '$..cpf', '$..pis', '$..nis', '$..rg', '$..cnh', '$..ctps',
                  '$..titulo_eleitor', '$..salario', '$..remuneracao', '$..conta', '$..senha'],
      replacement: '***'
    }
  });

  // --------------------------------------------------------------- sessão
  // Token gerado uma única vez por execução, compartilhado entre todas as threads
  var login = karate.callSingle('classpath:rhnet/support/auth/obter-token.feature', config);
  config.token = login.token;
  config.sessao = karate.fromJson(Java.type('rhnet.support.auth.Autenticacao').payloadJwt(login.token));
  karate.configure('headers', {
    Authorization: 'Bearer ' + login.token,
    Accept: 'application/json'
  });

  // ----------------------------------------------------------- relatórios
  // Anexa o texto ao passo atual, visível no relatório do Karate e no Allure
  config.registrar = function (texto) {
    karate.embed(texto, 'text/plain', 'Verificação');
  };

  // ------------------------------------------------------------- contrato
  // Valida a última resposta contra spec/<ambiente>/rhnetsocial.json.  Uso:  * validarContrato()
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

  return config;
}
