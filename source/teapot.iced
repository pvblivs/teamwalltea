cron = require 'cron'
http = require 'http'
read = require 'read'
fs = require 'fs'

username = null
password = null
projectId = process.argv[2]
teamCity = null

class TeamCity
    constructor: (@host, username, password) ->
        @authorization = 'Basic ' + new Buffer(username + ':' + password).toString 'base64'

    queryProject: (projectId, callback) ->
        buildStats = []
        await @_queryProject projectId, defer project
        await
            for buildType, i in project.buildTypes.buildType
                @queryBuildStats buildType, defer buildStats[i]
        callback project.name, buildStats

    queryBuildStats: (buildType, callback) ->
        buildStatQuery = "/httpAuth/app/rest/builds/buildType:#{buildType.id},canceled:false/statistics/SuccessRate"
        @_queryDefault buildStatQuery, (response) ->
            buildStat = { name: buildType.name, status: (if response == '1' then 'SUCCESS' else 'FAILURE') }
            #console.log 'Build stat: ' + JSON.stringify(buildStat)
            callback buildStat

    _queryProject: (projectId, callback) ->
        @_queryJson "/httpAuth/app/rest/projects/id:#{projectId}", (project) -> callback project

    _queryJson: (path, callback) ->
        @_query path, { accept: 'application/json' }, (jsonString) -> callback JSON.parse jsonString

    _queryDefault: (path, callback) ->
        @_query path, {}, callback, (resultString) -> callback resultString

    _query: (path, headers, callback) ->
        #console.log 'Querying:   ' + path
        headers.authorization = @authorization
        options = { host: @host, path: path, method: 'GET', headers: headers }
        call = http.request options, (response) ->
            resultString = ''
            response.on 'data', (lines) -> resultString += lines
            response.on 'end', -> callback resultString
        call.end()

await read { prompt: 'Username: '}, defer er, user
await read { prompt: 'Password: ', silent: true }, defer er, pwd

teamCity = new TeamCity 'teamcity', user, pwd

runTask = ->
    await teamCity.queryProject projectId, defer projectName, buildStats
    fs.writeFileSync 'results.json', "{ name: #{projectName}, chain: #{JSON.stringify(buildStats)} }"

new cron.CronJob { cronTime: "*/10 * * * * *", onTick: runTask, start: true }