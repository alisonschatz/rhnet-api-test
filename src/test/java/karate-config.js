/**
 * Configuração global do Karate. Roda antes de cada cenário.
 *
 *   Ambiente:     -Dkarate.env=hml | prd   (padrão: hml)
 *   URLs:         ambientes.json (raiz do projeto)
 *   Credenciais:  .env.<ambiente> (local) ou variáveis de ambiente (pipeline)
 *
 * Variáveis disponíveis em todas as features:
 *   baseUrl, authUrl       URLs da RH NET Social e da API de auth
 *   ambiente               hml | prd
 *   token                  JWT do usuário de teste (login feito uma vez por execução)
 *   sessao                 dados do JWT: sessao.sistemaId, sessao.usuario.dados.empresasVinculadas...
 *   validarContrato()      valida a última resposta contra spec/<ambiente>/rhnetsocial.json
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
  var arquivoEnv = {};
  var arquivo = new java.io.File('.env.' + ambiente);
  if (arquivo.exists()) {
    var linhas = Java.type('java.nio.file.Files').readAllLines(arquivo.toPath());
    for (var i = 0; i < linhas.size(); i++) {
      var linha = String(linhas.get(i)).trim();
      var igual = linha.indexOf('=');
      if (linha === '' || linha.charAt(0) === '#' || igual < 1) continue;
      arquivoEnv[linha.substring(0, igual).trim()] = linha.substring(igual + 1).trim();
    }
  }
  function credencial(nome) {
    var v = java.lang.System.getenv(nome);
    if (v == null || v === '') v = arquivoEnv[nome];
    return (v == null || v === '') ? null : v;
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
  // Mascara token, CPF e outros dados sensíveis em logs e relatórios (LGPD)
  karate.configure('logModifier', Java.type('rhnet.support.log.MascaradorLog').INSTANCE);

  // --------------------------------------------------------------- sessão
  // Login uma única vez por execução, compartilhado entre todas as threads
  var login = karate.callSingle('classpath:rhnet/support/auth/obter-token.feature', config);
  config.token = login.token;
  config.sessao = JSON.parse(Java.type('rhnet.support.auth.Autenticacao').payloadJwt(login.token));
  karate.configure('headers', {
    Authorization: 'Bearer ' + login.token,
    Accept: 'application/json'
  });

  // ------------------------------------------------------------- contrato
  // Valida a última resposta contra spec/<ambiente>/rhnetsocial.json.  Uso:  * validarContrato()
  var Validador = Java.type('rhnet.support.contrato.ValidadorContrato');
  config.validarContrato = function () {
    var req = karate.prevRequest;
    var erros = Validador.validate(ambiente, 'rhnetsocial',
      req.method, req.url, karate.get('responseStatus'), karate.get('responseBytes'));
    if (erros) {
      karate.fail('\n' + erros);
    }
    var caminho = String(req.url).replace(/^https?:\/\/[^\/]+/, '').split('?')[0];
    karate.log('Contrato válido: ' + req.method + ' ' + caminho + ' (status ' + karate.get('responseStatus')
      + ') está em conformidade com spec/' + ambiente + '/rhnetsocial.json');
  };

  return config;
}
