// Configuracao minima do Node-RED da proposta do item 3 (equipe 1 -> equipe 2).
// Usuario e senha do editor, do MQTT e do PostgreSQL vem do ambiente (.env); nada fica gravado aqui.
const crypto = require('crypto');

function igual(a, b) {
  const x = Buffer.from(String(a || ''));
  const y = Buffer.from(String(b || ''));
  return x.length > 0 && x.length === y.length && crypto.timingSafeEqual(x, y);
}

module.exports = {
  flowFile: 'flows.json',
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
