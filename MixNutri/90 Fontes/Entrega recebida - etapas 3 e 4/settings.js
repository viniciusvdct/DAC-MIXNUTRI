module.exports = {
  functionExternalModules: true,
  functionTimeout: 10,
  functionGlobalContext: { pg: require('pg'), nodemailer: require('nodemailer') },
  editorTheme: { projects: { enabled: false } },
  credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET || 'troque-esta-chave'
};
