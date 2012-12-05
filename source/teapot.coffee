cron = require 'cron'
http = require 'http'
read = require 'read'
async = require 'async'
fs = require 'fs'

username = null
password = null
projectId = process.argv[2]
teamCity = null

class TeamCity
    constructor: (@host, username, password) ->
        @authorization = 'Basic ' + new Buffer(username + ':' + password).toString 'base64'

    queryProject: (projectId, callback) ->
        @_queryJson "/httpAuth/app/rest/projects/id:#{projectId}", (project) -> 
            callback project

    queryBuildStats: (buildType, callback) ->
        @_queryDefault "/httpAuth/app/rest/builds/buildType:#{buildType.id},canceled:false/statistics/SuccessRate", (response) ->
            callback null, { name: buildType.name, status: (if response == '1' then 'SUCCESS' else 'FAILURE') }

    _queryJson: (path, callback) ->
        @_query path, { accept: 'application/json' }, (resultString) -> callback JSON.parse resultString

    _queryDefault: (path, callback) ->
        @_query path, {}, callback, (resultString) -> callback resultString

    _query: (path, headers, callback) ->
        # console.log 'Querying ' + path
        headers.authorization = @authorization
        options = { host: @host, path: path, method: 'GET', headers: headers }

        call = http.request options, (response) ->
            resultString = ''
            response.on 'data', (lines) -> resultString += lines
            response.on 'end', -> callback resultString
        call.end()

createBuildStatQueries = (project) ->
    chain = project.buildTypes.buildType.map (buildType) ->
        (callback) ->
            teamCity.queryBuildStats buildType, callback

startJob = ->
    runTask = ->
        teamCity.queryProject projectId, (project) ->
            async.parallel createBuildStatQueries(project), (err, queryResults) ->
                fs.writeFile 'results.json', "{ name: #{project.name}, chain: #{JSON.stringify(queryResults)} }"

    new cron.CronJob { cronTime: "*/10 * * * * *", onTick: runTask, start: true }

read { prompt: 'Username: '}, (er, user) ->
    read { prompt: 'Password: ', silent: true }, (er, pwd) ->
        teamCity = new TeamCity 'teamcity', user, pwd

        startJob()