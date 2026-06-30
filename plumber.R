#* @get /qb
function(name = "", season = 2024) {
  source("server.R")
  get_qb(name, season)
}
