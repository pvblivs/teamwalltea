cron = require 'cron'
http = require 'http'
read = require 'read'
async = require 'async'
fs = require 'fs'

username = null
password = null
projectId = process.argv[2]

query = (path, headers, callback) ->
    # console.log 'Querying ' + path
    headers.authorization = 'Basic ' + new Buffer(username + ':' + password).toString 'base64'
    options = { host: 'teamcity', path: path, method: 'GET', headers: headers }

    call = http.request options, (response) ->
        resultString = ''
        response.on 'data', (lines) -> resultString += lines
        response.on 'end', -> callback resultString
    call.end()

queryJson = (path, callback) ->
    query path, { accept: 'application/json' }, (resultString) -> callback JSON.parse resultString

queryDefault = (path, callback) ->
    query path, {}, callback, (resultString) -> callback resultString

queryProject = (projectId, callback) ->
    queryJson "/httpAuth/app/rest/projects/id:#{projectId}", (project) -> 
        callback project

queryBuildStats = (buildType, callback) ->
    queryDefault "/httpAuth/app/rest/builds/buildType:#{buildType.id},canceled:false/statistics/SuccessRate", (response) ->
        callback(null, { name: buildType.name, status: (if response == '1' then 'SUCCESS' else 'FAILURE') })

createBuildStatQueries = (project) ->
    chain = project.buildTypes.buildType.map (buildType) -> 
        (callback) -> 
            queryBuildStats buildType, callback   

startJob = ->
    runTask = ->
        queryProject projectId, (project) ->
            async.parallel createBuildStatQueries(project), (err, queryResults) ->
                fs.writeFile 'results.json', "{ name: #{project.name}, chain: #{JSON.stringify(queryResults)} }"

    new cron.CronJob { cronTime: "*/10 * * * * *", onTick: runTask, start: true }

read { prompt: 'Username: '}, (er, user) ->
    read { prompt: 'Password: ', silent: true }, (er, pwd) ->
        username = user
        password = pwd

        startJob()