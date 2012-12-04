cron = require 'cron', http = require 'http', read = require 'read'

startJob = (username, password, buildType) ->
    options = {
        host: 'teamcity',
        path: "/httpAuth/app/rest/builds/buildType:bt#{buildType},lookupLimit:1",
        method: 'GET',
        headers: {
            accept: 'application/json',
            authorization: 'Basic ' + new Buffer(username + ':' + password).toString 'base64'
        }
    }

    readBuilds = (response) ->
        buildDataString = ''

        response.on 'data', (lines) ->
            buildDataString += lines
            
        response.on 'end', ->
            buildData = JSON.parse buildDataString
            console.log buildData.status

    runTask = ->
        call = http.request options, readBuilds
        call.end()

    new cron.CronJob {
        cronTime: "*/10 * * * * *",
        onTick: runTask,
        start: true
    }

read { prompt: 'Username: '}, (er, username) ->
    read { prompt: 'Password: ', silent: true }, (er, password) ->
        startJob username, password, process.argv[2]