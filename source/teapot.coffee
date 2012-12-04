cron = require 'cron', http = require 'http', read = require 'read', async = require 'async'

query = (path, username, password, headers, callback) ->
    console.log 'Querying ' + path
    options = { host: 'teamcity', path: path, method: 'GET', headers: headers }
    options.headers.authorization = 'Basic ' + new Buffer(username + ':' + password).toString 'base64'

    readResult = (response) ->
        resultString = ''
        response.on 'data', (lines) -> resultString += lines
        response.on 'end', -> callback resultString

    call = http.request options, readResult
    call.end()

queryJson = (path, username, password, callback) ->
    query path, username, password, { accept: 'application/json' }, (resultString) -> callback JSON.parse resultString

queryDefault = (path, username, password, callback) ->
    query path, username, password, {}, callback, (resultString) -> callback resultString

startJob = (username, password) ->
    runTask = ->
        queryJson "/httpAuth/app/rest/projects/id:project14", username, password, (response) ->
            chain = response.buildTypes.buildType.map (buildType) ->
                (callback) ->
                    queryDefault "/httpAuth/app/rest/builds/buildType:#{buildType.id},canceled:false/statistics/SuccessRate", username, password, (response) ->
                        callback(null, { name: buildType.name, status: (if response == '1' then 'SUCCESS' else 'FAILURE') })

            async.parallel chain, (err, results) ->
                console.log results

    new cron.CronJob {
        cronTime: "*/10 * * * * *",
        onTick: runTask,
        start: true
    }

read { prompt: 'Username: '}, (er, username) ->
    read { prompt: 'Password: ', silent: true }, (er, password) ->
        startJob username, password