// Configuracao minima do Node-RED da proposta do item 3 (equipe 1 -> equipe 2).
// Usuario e senha do editor, do MQTT e do PostgreSQL vem do ambiente (.env); nada fica gravado aqui.
const crypto = require('crypto');

function igual(a, b) {
  const x = Buffer.from(String(a || ''));
  const y = Buffer.from(String(b || ''));
  return x.length > 0 && x.length === y.length && crypto.timingSafeEqual(x, y);
}

function autorizado(cabecalho) {
  const [tipo, valor] = String(cabecalho || '').split(' ');
  if (tipo !== 'Basic' || !valor) return false;
  const texto = Buffer.from(valor, 'base64').toString();
  const i = texto.indexOf(':');
  return i > 0 && igual(texto.slice(0, i), process.env.NODERED_ADMIN_USUARIO)
    && igual(texto.slice(i + 1), process.env.NODERED_ADMIN_SENHA);
}

// Paginas HTTP dos nos (painel Admin do Dashboard 2.0) pedem o mesmo usuario do editor.
function autenticarPainel(req, res, next) {
  if (autorizado(req.headers.authorization)) return next();
  res.set('WWW-Authenticate', 'Basic realm="MixNutri Admin"');
  return res.status(401).send('Autenticacao necessaria');
}

// O socket.io do Dashboard 2.0 nao passa pelo middleware HTTP: repete as verificacoes padrao
// (sem websocket direto, mesma origem) e exige o mesmo usuario.
function autenticarSocket(socket, next) {
  if (socket.client.conn.request.url.indexOf('transport=websocket') !== -1) {
    socket.client.conn.close();
    return undefined;
  }
  if (socket.handshake.xdomain === false && autorizado(socket.handshake.headers.authorization)) return next();
  return socket.disconnect(true);
}

module.exports = {
  flowFile: 'flows.json',
  httpNodeMiddleware: autenticarPainel,
  // O Dashboard 2.0 serve as paginas por conta propria: precisa do mesmo login nos dois canais.
  dashboard: { middleware: autenticarPainel, ioMiddleware: autenticarSocket },
  flowFilePretty: true,
  // flows_cred.json contem apenas referencias ${VAR}; sem segredo para cifrar.
  credentialSecret: false,
  uiPort: process.env.PORT || 1880,
  adminAuth: {
    type: 'credentials',
    users: async (nome) =>
      (nome === process.env.NODERED_ADMIN_USUARIO ? { username: nome, permissions: '*' } : null),
    authenticate: async (nome, senha) =>
      (igual(nome, process.env.NODERED_ADMIN_USUARIO) && igual(senha, process.env.NODERED_ADMIN_SENHA)
        ? { username: nome, permissions: '*' } : null),
  },
  diagnostics: { enabled: true, ui: false },
  runtimeState: { enabled: false, ui: false },
  telemetry: { enabled: false },
  logging: { console: { level: 'info', metrics: false, audit: false } },
  editorTheme: { projects: { enabled: false }, tours: false },
};
