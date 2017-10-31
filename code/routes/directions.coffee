uuidv4 = require 'uuid/v4'
_ = require 'lodash'
googleMaps = require('@google/maps').createClient
  key: process.env.GOOGLE_MAPS_DIRECTIONS_API_KEY
  Promise: Promise

requests = {};

module.exports = [
  path: '/route'
  method: 'POST'
  handler: (request, reply)->
    # VALIDATION
    # just in case caller fails to specify content type
    if typeof request.payload is 'string'
      try
        request.payload = JSON.parse request.payload
      catch e
        reply 'failed to parse input'
    # is input an array?
    unless Array.isArray request.payload then return reply {error: 'input should be an array'}
    # is input array empty?
    unless request.payload.length then return reply {error: 'input cannot be empty'}
    # is each child an array of two strings?
    for latlon in request.payload
      unless Array.isArray latlon then return reply {error: 'each element of input should be an array'}
      unless latlon.length is 2 then return reply {error: 'each element of input a 2 element array'}
      unless typeof latlon[0] is 'string' then return reply {error: 'latlon tuples should consist of strings'}
      unless typeof latlon[1] is 'string' then return reply {error: 'latlon tuples should consist of strings'}

    # DO THE THING
    token = uuidv4()
    requests[token] = 'in progress'
    # figure out waypoints
    waypoints = request.payload.slice()
    waypoints.shift()
    waypoints.pop()
    # call api
    googleMaps
      .directions
        origin: request.payload[0]
        destination: request.payload[request.payload.length-1]
        waypoints: waypoints
      .asPromise()
      .then (result)->
        requests[token] =
          status: 'success'
          path: request.payload
          result: result
      .catch (result)->
        console.log(result) # logs might be useful when users ask why
        requests[token] =
          status: 'failure'
          error: result
    # return the token
    reply token: token
,
  path: '/route/{token}'
  method: 'GET'
  handler: (request, reply)->
    token = request.params.token
    # VALIDATION
    # does token exist?
    unless requests[token] then return reply {status:'failure', error:'token does not exist'}
    # still in progress?
    if requests[token] is 'in progress' then return reply {status:'in progress'}
    # did directions api fail?
    if requests[token].status is 'failure' then return reply {status:'failure', error:'maps api call failed'}

    # DO THE THING
    # compute shortest route
    routes = _.map requests[token].result.json.routes, (route)->
      distance: _.reduce route.legs, ((sum, leg)->sum+leg.distance.value), 0
      duration: _.reduce route.legs, ((sum, leg)->sum+leg.duration.value), 0
    shortestRoute = _.minBy routes, 'distance'
    # return
    reply
      status: 'success'
      path: requests[token].path
      total_distance: shortestRoute.distance
      total_time: shortestRoute.duration
]
