Hapi = require 'hapi'
server = new Hapi.Server

# initialize
server.connection
  host: '0.0.0.0'
  port: process.env.PORT or 3000
  routes: cors: true

# load routes
server.register {
  register: require('hapi-router-coffee')
  options: routesDir: "#{__dirname}/routes/"
}, (err)-> throw err if err

# kick start
server.start (err) ->
  if err then throw err
  console.log "server started on #{server.info.uri}"

