cron = require 'cron', http = require 'http', read = require 'read'

query = (path, username, password, callback) ->
    console.log 'Querying ' + path
    options = {
        host: 'teamcity',
        path: '/httpAuth/app/rest/' + path,
        method: 'GET',
        headers: {
            accept: 'application/json',
            authorization: 'Basic ' + new Buffer(username + ':' + password).toString 'base64'
        }
    }

    readResult = (response) ->
        resultString = ''

        response.on 'data', (lines) ->
            resultString += lines
            
        response.on 'end', ->
            json = JSON.parse resultString
            callback(json)

    call = http.request options, readResult
    call.end()

startJob = (username, password, buildType) ->
    runTask = ->
        query "builds/buildType:bt#{buildType},lookupLimit:1", username, password, (response) ->
            console.log response.status

    new cron.CronJob {
        cronTime: "*/10 * * * * *",
        onTick: runTask,
        start: true
    }

read { prompt: 'Username: '}, (er, username) ->
    read { prompt: 'Password: ', silent: true }, (er, password) ->
        startJob username, password, process.argv[2]