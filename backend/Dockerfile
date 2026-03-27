FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

# 创建 uploads 目录（本地存储用）
RUN mkdir -p uploads

EXPOSE 3001

CMD ["node", "src/index.js"]
