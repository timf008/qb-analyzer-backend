FROM r-base:4.3.1

# System dependencies for plumber, sodium, nflreadr, tidyverse
RUN apt-get update && apt-get install -y \
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

# Install remotes so we can install plumber from GitHub
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org')"

# Install plumber from GitHub (fixes sodium issues)
RUN R -e "remotes::install_github('rstudio/plumber')"

# Install other packages from CRAN
RUN R -e "install.packages(c('nflreadr', 'dplyr', 'tidyr', 'jsonlite'), repos='https://cloud.r-project.org')"

# Copy backend files
WORKDIR /app
COPY . /app

# Expose port
EXPOSE 8000

# Run plumber API
CMD ["R", "-e", "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"]
