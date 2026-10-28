# Node-RED da proposta do item 3: no PostgreSQL (cliente pg em JavaScript puro) e o mesmo
# Dashboard 2.0 usado pela outra equipe, ambos em versao fixa.
FROM nodered/node-red:4.1.16-22-minimal
RUN npm install --omit=dev --no-audit --no-fund --no-update-notifier \
      node-red-contrib-postgresql@0.16.2 @flowfuse/node-red-dashboard@1.29.0
