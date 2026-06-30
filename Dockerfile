# ============================================================
# Base image: Node (because server.js is the actual web server)
# ============================================================
FROM node:18

# ============================================================
# Install R and system dependencies for nflreadr, tidyverse, plumber
# ============================================================
RUN apt-get update && apt-get install -y \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libsodium-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Install R packages
# ============================================================
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org')"
RUN R -e "remotes::install_github('rstudio/plumber')"   # optional, safe to keep
RUN R -e "install.packages(c('nflreadr','dplyr','tidyr','jsonlite'), repos='https://cloud.r-project.org')"

# ============================================================
# Install Node dependencies
# ============================================================
WORKDIR /app
COPY package.json /app/package.json
RUN npm install

# ============================================================
# Copy backend files (server.js, nflreadr.R, etc.)
# ============================================================
COPY . /app

# ============================================================
# Expose Node port (your server.js uses 8080)
# ============================================================
EXPOSE 8080

# ============================================================
# Run Node backend (NOT plumber)
# ============================================================
CMD ["node", "server.js"]

