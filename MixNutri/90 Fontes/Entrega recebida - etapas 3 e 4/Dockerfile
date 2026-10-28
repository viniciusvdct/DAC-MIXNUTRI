FROM nodered/node-red:4.0.9
COPY package.json /data/package.json
RUN cd /data && npm install --omit=dev --no-audit --no-fund && npm cache clean --force
COPY --chown=node-red:node-red settings.js flows.json /data/
ENV FLOWS=flows.json
USER node-red
