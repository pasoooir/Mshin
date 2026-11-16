FROM node:22-alpine
WORKDIR /app
COPY package.json ./package.json
COPY src ./src
RUN mkdir -p /var/lib/mshin && chown -R node:node /app /var/lib/mshin
ENV NODE_ENV=production
ENV PORT=8788
ENV MSHIN_DATA_DIR=/var/lib/mshin
USER node
EXPOSE 8788
CMD ["node", "src/index.mjs"]
