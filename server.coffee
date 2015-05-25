
# config (webroot, port) from
_CONF_PATH = './config/conf.json' # to be displayed in terminal

conf = require _CONF_PATH
package_json = require './package.json'
net = require 'net'
fs = require 'fs'
path = require 'path'
stream = require 'stream'


## CONSTANTS ##

# The Server configuration constants
_SERVER_NAME = package_json.name
_SERVER_VERSION = package_json.version
_SERVER_DESCRIPTION = package_json.description
_SERVER_DESCRIPTION_SEQUEL = package_json.descriptionSequel
_SERVER_AUTHOR = package_json.author
_SERVER_LICENCE = package_json.license
_SERVER_HOMEPAGE = package_json.homepage

_SERVER_PROTOCOL_VERSION = '1.0' # The server only handles HTTP version 1.0
_SERVER_INTERNAL_CONFIG = 'assets'

# The port to use
_PORT = conf.port

# The web root folder
_WEBROOT = conf.webroot

# The default index file
_INDEX = conf.defaultIndex

# The HTML Footer Message
_FOOTER = conf.html_Footer_onError

# Debug mode (true or false)
_DEBUG = conf.debug



# The Statut Codes Array
statusCodeArray =
	200: 'OK !!' # yeah baby !!
	302: 'Redirect !!'
	400: 'Bad Request !!' # you're talking to me ??
	403: 'Forbidden Access !!' # No Way !!
	404: 'Not Found !!' # No idea what you want !!
	408: 'Request timeOut !!' # Too Long, Can't Wait !!
	500: 'Internal Server Error !!' # I'm broken... You broke me !!
	501: 'Not Implemented' # No can do !!!

funnyErrorCodeArray =
	400: "You're talking to me ??"
	403: "No Way !!"
	404: "No idea what you want !!"
	408: "Too Long, Can't Wait !!"
	500: "I'm broken... You broke me !!"
	501: "No can do !!!"

# The HTML Messages on Errors
htmlErrorMessage =
	400: 'BAD REQUEST : The request received can\'t be understood !!'
	403: 'FORBIDDEN : You are NOT allowed to access this ressource !!'
	404: 'NOT FOUND : The page you\'re looking for doesn\'t exist !!'
	408: 'TIMEOUT : The request has takken too long to complete !!'
	414: 'TOO LONG : The Requested URI is too long !!'
	500: 'INTERNAL ERROR : The server has encountered an Internal Error !!'
	501: 'NOT IMPLEMENTED : This fonctionality isn\'t implemented'

# The Content-Types Array
contentTypeArray =
	html: 'text/html'
	txt: 'text/plain'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	png: 'image/png'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	gif: 'image/gif'
	mp3: 'audio/mpeg3'
	mp4: 'video/mpeg'

# REGEX
# checks that the request status line looks like : GET /images/test.css HTTP/1.0
_STATUSLINE_RG = /^([A-Z]+) +((\/*[^\s]*)\/+([^\s]*)) +([A-Z]+)\/(.+)\r\n/


######## MAIN #########


# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket, responds to the request
	socket.on 'data', (reqHeader)->
		new Request(reqHeader).process (infos)->
			new Response(infos).process socket

	# SOCKET error, log it and close the socket (socket closed automaticaly when 'error' event is fired)
	socket.on 'error', (err)->
		if _DEBUG
			console.error 'SOCKET.ERROR : il y a une erreur:', err.toString 'utf8' + '\n'


# Launch the server and listen to port 3333
server.listen _PORT, ->
	console.log '\n'
	console.log '###############################################################################'
	console.log '\n'
	console.log " 		 #{_SERVER_NAME} v#{_SERVER_VERSION} WebServer ONline on port: #{_PORT}\n"
	console.log "    		   #{_SERVER_DESCRIPTION}"
	console.log "  	#{_SERVER_DESCRIPTION_SEQUEL}"
	console.log '\n'
	console.log '###############################################################################'
	console.log '\n'

	if !_DEBUG
		console.log "Debug Mode: #{_DEBUG}\n"
		console.log "Author: #{_SERVER_AUTHOR}"
		console.log "License: #{_SERVER_LICENCE}"
		console.log "WebRoot : #{_WEBROOT}"
		console.log "Configuration file: #{_CONF_PATH}\n"
		console.log "Project Homepage : #{_SERVER_HOMEPAGE}"
		console.log '\n'
	else
		console.log "Debug Mode: #{_DEBUG}\n"
		console.log "Configuration file: #{_CONF_PATH}"
		console.log "WebRoot : #{_WEBROOT}"
		console.log "Assets : #{_SERVER_INTERNAL_CONFIG}"
		console.log "Default Index file : #{_INDEX}"
		console.log "Default Footer : #{_FOOTER}\n"
		console.log "Project Homepage : #{_SERVER_HOMEPAGE}"
		console.log '\n'



class Request

	constructor : (@reqHeader)->

		@requestFields = @parseHeader() # Parse the request Header and returns an object with all the fields
		@root = _WEBROOT
		@statusCode = 200


	parseHeader : ->
		strHeader = @reqHeader.toString 'utf8'
		statusLineFields = _STATUSLINE_RG.exec strHeader

		if statusLineFields is null
			null

		if _DEBUG
			console.log '>>>>>>>>>>> Request Header :\n', strHeader, '\n'
			console.log '>>>>>>>>>>> StatusLine Fields :\n', statusLineFields, '\n'

		statusLine = (statusLineFields[0].split('\\'))[0]

		requestInfos =
			# statusLine: statusLine
			method: statusLineFields[1]
			fullPath: statusLineFields[2] # path + file
			path: statusLineFields[3] # just the path, no file
			file: statusLineFields[4] # file + extension
			protocol: statusLineFields[5]
			protocolVersion: statusLineFields[6]

		requestInfos

	process : (callback) ->

		folder = @isFolder @requestFields
		fullPath = @requestFields.fullPath
		fullPathArray = fullPath.split '/'

		if @requestFields is null then @statusCode = 400 # Bad request

		if @requestFields.method is 'POST' then @statusCode =  501 # not implemented

		if fullPathArray[1] is _SERVER_INTERNAL_CONFIG
			@root = '.'

		if fullPath is '/'
			target = path.join @root, _INDEX

		else if folder
			tmpPath = path.join __dirname, @root, fullPath, _INDEX
			target = tmpPath

		else
			target = path.join @root, fullPath

		fs.stat target, (err, stats)=>
			if err
				try
					if (path.basename target) is _INDEX
						tmpPath = path.join path.dirname target
					else
						tmpPath = target

					fs.accessSync tmpPath
					@statusCode = 403 # forbidden
				catch err
					@statusCode =  404 # not found
					tmpPath = fullPath
			else
				isDirectory = stats.isDirectory()

				if isDirectory && !folder
					@statusCode = 302
					tmpTarget = fullPath + '/'
				else
					tmpTarget = target

			if @statusCode is 200 # if OK...
				fileToProcess = fs.createReadStream tmpTarget
				lastModified = stats.mtime
				fileSize = stats.size
				contentType = @getMIMEfromPath tmpTarget
				location = null

			else if @statusCode is 302
				location = tmpTarget
				lastModified = null
				fileSize = null
				contentType = null

			else # if any error...
				fileToProcess = new ErrorPage(@statusCode).getErrorPage()
				lastModified = new Date
				contentType = 'text/html'
				location = null

			infos =
				request:
					statusCode: @statusCode
					method: @requestFields.method
					protocol: @requestFields.protocol
					protocolVersion: @requestFields.protocolVersion
				file:
					name: @requestFields.file
					fileToProcess: fileToProcess
					MIMEType: contentType
					mtime : lastModified
					size: fileSize
					location: location

			callback infos

	isFolder : (reqInfos) ->

		file = reqInfos.file
		if file is '' || file is undefined
			if _DEBUG
				console.log '>>>>>>>>> is a Directory: TRUE :', file
			true
		else
			if _DEBUG
				console.log '>>>>>>>>> is a Directory: FALSE:', file
			false

	# Gets the MIME content-type from the file extension... returns the MIMEType of the file as a string
	getMIMEfromPath : (filePath)->

		realPath = path.normalize(filePath) # to take care of // or /.. or /.
		extension = path.extname realPath
		extension = extension.substr 1
		contentType = contentTypeArray[extension]

		if contentType is undefined
			contentType = 'text/html'

		contentType



class Response
	constructor : (@infos)->

	buildHeader : (callback) ->
		setTimeout =>
			#File Infos
			statusCode = @infos.request.statusCode
			protocol = @infos.request.protocol
			protocolVersion = @infos.request.protocolVersion
			fileSize = @infos.file.size
			filelastModified = @infos.file.mtime
			contentType = @infos.file.MIMEType
			redirectLocation = @infos.file.location

			# Get the Statut Message from the Statut Code
			statusMessage = statusCodeArray[statusCode]

			# Verify that the protocol version is handled by the server, if not, changes the protocol version to the server's
			if protocolVersion isnt _SERVER_PROTOCOL_VERSION
				if protocolVersion > _SERVER_PROTOCOL_VERSION
					protocolVersion  = _SERVER_PROTOCOL_VERSION

			if callback
				respHeader =
					statusLine:
						protocol: protocol
						protocolVersion: protocolVersion
						statusCode: statusCode
						statusMessage: statusMessage

					fields:
						Date: new Date
						'Content-Type': contentType
						'Content-Length': fileSize
						'Last-Modified': filelastModified
						Location: redirectLocation
						Server: "#{_SERVER_NAME}/#{_SERVER_VERSION}"

					toString : =>
						crlf = '\r\n'
						header = "#{protocol}/#{protocolVersion} #{statusCode} #{statusMessage}#{crlf}"
						for key, value of respHeader.fields
							if value isnt null
								header += "#{key}: #{value}#{crlf}"
						header + crlf

				callback respHeader
		,0

	process : (socket) ->
		fileToProcess = @infos.file.fileToProcess
		statusCode = @infos.request.statusCode
		method = @infos.request.method

		if @isReadableStream fileToProcess

			@buildHeader (respHeader)=>

				socket.write respHeader.toString(), =>
					if _DEBUG
						console.log "FILESTREAM.OPEN : #{@infos.file.name} est ouvert !!\n"
					fileToProcess.pipe socket

				fileToProcess.on 'end', =>
					if _DEBUG
						console.log "FILESTREAM.END : #{@infos.file.name} à été servit !!\n\n"
					socket.end()

				fileToProcess.on 'error', (err)=>
					console.error "FILESTREAM.ERROR : il y a une erreur:", err['code'],
					"avec le fichier : #{@infos.file.name}\n"

		else if statusCode is 302 || method is 'HEAD'

			@buildHeader (respHeader)=>
				socket.end respHeader.toString()

		else
			@infos.file.size = Buffer.byteLength fileToProcess, 'utf8'

			@buildHeader (respHeader)=>
				socket.write respHeader.toString(), =>
					socket.end new ErrorPage(statusCode).getErrorPage()

	# Checks that an object is a readable qstream or not... returns true/false
	isReadableStream : (obj)->

		obj instanceof stream.Stream && typeof obj.open is 'function'



class ErrorPage
	ErrorPage.footer = _FOOTER
	constructor:  (statusCode) ->
		if !statusCode
			statusCode = 500
		errorMessage = htmlErrorMessage[statusCode]
		funnyMessage = funnyErrorCodeArray[statusCode]

		@htmlErrorPage = "<!DOCTYPE HTML>
			<html>
				<head>
				<meta charset='UTF-8'>
				<title>Error : #{funnyMessage}</title>
				</head>
				<body>
					<div align='center'><img src='/assets/img/ban.png'></i></div>
						<div style='height:450px'>
							<h1 align='center'>ERROR #{statusCode}</h1>
							<h2 align='center'>#{funnyMessage}</h2>
						</div>
				</body>
				<footer>
					<h2 align='center'>#{errorMessage}</h2>
					<p align='center'>#{ErrorPage.footer}</p>
					<p align='center'>ERROR #{statusCode} : #{funnyMessage}</p>
				</footer>
			</html>"

	getErrorPage : ->
		@htmlErrorPage
