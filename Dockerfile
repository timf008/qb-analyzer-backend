FROM node:18-slim

# Install R (minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install only the R packages you actually use
RUN R -e "install.packages(c('nflreadr','dplyr','tidyr','jsonlite'), repos='https://cloud.r-project.org')"

# Node setup
WORKDIR /app
COPY package.json .
RUN npm install

COPY . .

EXPOSE 8080
CMD ["node", "server.js"]


