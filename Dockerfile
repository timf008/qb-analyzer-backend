# ============================================================
# Base image: Node (server.js is the actual web server)
# ============================================================
FROM node:18-slim

# ============================================================
# Install R (minimal) + required system libs
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Install only the R packages your backend actually uses
# ============================================================
RUN R -e "install.packages(c('nflreadr','dplyr','tidyr','jsonlite'), repos='https://cloud.r-project.org')"

# ============================================================
# Preload ALL seasons needed for Trend / Compare / Rank
# ============================================================
RUN R -e "for (s in c(2020,2021,2022,2023,2024,2025)) { \
    pbp <- nflreadr::load_pbp(s); \
    saveRDS(pbp, paste0('pbp_cache_', s, '.rds')); \
}"

# ============================================================
# Node setup
# ============================================================
WORKDIR /app
COPY package.json /app/package.json
RUN npm install

# Copy backend files (server.js, nflreadr.R, etc.)
COPY . /app

# ============================================================
# Expose Node port
# ============================================================
EXPOSE 8080

# ============================================================
# Start Node backend
# ============================================================
CMD ["node", "server.js"]

