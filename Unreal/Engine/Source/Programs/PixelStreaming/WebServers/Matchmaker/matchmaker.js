// Copyright Epic Games, Inc. All Rights Reserved.
var enableRedirectionLinks = true;
var enableRESTAPI = true;

// Microsoft Notes: This file has additions to the Unreal Engine Matchmaker that were done in conjunction with Epic to
// add improved capabilities, resiliency and abilities to deploy and scale Pixel Streaming in Azure.
// "MSFT Improvement" -- Areas where Microsoft have added additional code to what is exported out of Unreal Engine
// "AZURE" -- Areas where Azure specific code was added (i.e., modules/azure.js, scale up/down, logging, metrics, etc.)

//////////////////////////// MSFT Improvement  ////////////////////////////
// Added a config file for Matchmaker (MM)
const defaultConfig = {
	// The port clients connect to the matchmaking service over HTTP
	httpPort: 90,
	httpsPort: 443,
	enableHttps: false,
	// The matchmaking port the signaling service connects to the matchmaker
	matchmakerPort: 9999,

	/////////////////////////////// AZURE ///////////////////////////////
	// Enables authentication checks for hitting the MM and SS
	enableAuthentication: false,
	// The amount of instances deployed per node, to be used in the autoscale policy (i.e., 1 unreal app running per GPU VM) -- FUTURE
	instancesPerNode: 1,
	// The amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	instanceCountBuffer: 5,
	// The percentage amount of available signaling service / App instances we want to ensure are available before we have to scale up (0 will ignore)
	percentBuffer: 25,
	// The minimum number of available app instances we want to scale down to during an idle period
	minInstanceCount: 0,
	// The total amount of VMSS nodes that we will approve scaling up to
	maxInstanceCount: 500,
	// The subscription used for autoscaling policy
	subscriptionId: "",
	// The Azure ResourceGroup where the Azure VMSS is located, used for autoscaling
	resourceGroup: "",
	// The Azure VMSS name used for scaling the Signaling Service / Unreal App compute
	virtualMachineScaleSet: "",
	// Azure App Insights ID for logging
	appInsightsInstrumentationKey: "",
	// Log to file
	LogToFile: true,
	// Number of seconds between scaling evaluations
	scalingEvaluationInterval: 30,
	// Lifecycle management enabled
	enableLifecycleManagement: false,
	// When enableAuthentication is true, the "mm_authenticated" cookie expiration (ms -- default 1 min) before being redirected back to MM
	authCookieExpirationMaxAge: 60000,
	// How long the cookie "mm_address" stays alive (ms) that lets the SS know the full DNS of the MM to redirect back if auth is enabled
	mmAddressCookieExpirationMaxAge: 2592000000
	/////////////////////////////////////////////////////////////////////

};

// Similar to the Signaling Server (SS) code, load in a config.json file for the MM parameters
const argv = require('yargs').argv;

var configFile = (typeof argv.configFile != 'undefined') ? argv.configFile.toString() : '.\\config.json';
console.log(`configFile ${configFile}`);
const config = require('./modules/config.js').init(configFile, defaultConfig);
console.log("Config: " + JSON.stringify(config, null, '\t'));
///////////////////////////////////////////////////////////////////////////

const express = require('express');
var cors = require('cors');
const app = express();
const http = require('http').Server(app);
const fs = require('fs');
const path = require('path');
const bodyParser = require('body-parser');
const logging = require('./modules/logging.js');
logging.RegisterConsoleLogger();

if (config.LogToFile) {
	logging.RegisterFileLogger('./logs');
}

/////////////////////////////// AZURE ///////////////////////////////
// Initialize the Azure module for scale and metric functionality
const ai = require('./modules/ai.js')
ai.init(config);
const autoscale = require('./modules/autoscale.js')
const connectionMgr = require('./modules/connectionManager.js');
if(config.enableLifecycleManagement) {
	require('./modules/api.js').init(config, ai);
	require('./modules/lifecycleCheck.js').init(config, ai);
}

autoscale.init(config, ai);
connectionMgr.init(ai);

// Added for health check of the VM/App when using Azure Traffic Manager
app.get('/ping', (req, res) => {
	res.send('ping');
});
/////////////////////////////////////////////////////////////////////

// Setup public folder
app.use(express.static(path.join(__dirname, '/public')));

// A list of all the Cirrus server which are connected to the Matchmaker.
var cirrusServers = new Map();

//
// Parse command line.
//

if (typeof argv.httpPort != 'undefined') {
	config.httpPort = argv.httpPort;
}
if (typeof argv.matchmakerPort != 'undefined') {
	config.matchmakerPort = argv.matchmakerPort;
}

http.listen(config.httpPort, () => {
    console.log('HTTP listening on *:' + config.httpPort);
});


//////////////////////////// MSFT Improvement  ////////////////////////////
// Added HTTPS code for Matchmaker from SS (due to some corporate policies requiring it)
if (config.enableHttps) {
	//HTTPS certificate details
	const options = {
		key: fs.readFileSync(path.join(__dirname, './certificates/client-key.pem')),
		cert: fs.readFileSync(path.join(__dirname, './certificates/client-cert.pem'))
	};

	var https = require('https').Server(options, app);

	//Setup http -> https redirect
	console.log('Redirecting http->https');
	app.use(function (req, res, next) {
		if (!req.secure) {
			if (req.get('Host')) {
				var hostAddressParts = req.get('Host').split(':');
				var hostAddress = hostAddressParts[0];
				if (config.httpsPort != 443) {
					hostAddress = `${hostAddress}:${httpsPort}`;
				}
				return res.redirect(['https://', hostAddress, req.originalUrl].join(''));
			} else {
				console.error(`unable to get host name from header. Requestor ${req.ip}, url path: '${req.originalUrl}', available headers ${JSON.stringify(req.headers)}`);
				return res.status(400).send('Bad Request');
			}
		}
		next();
	});

	https.listen(443, function () {
		console.log('Https listening on 443');
	});
}

//If not using authetication then just move on to the next function/middleware
var isAuthenticated = (redirectUrl) =>
  function (req, res, next) {
    return next();
  };

if (config.enableAuthentication && config.enableHttps) {
  var passport = require('passport');
  require('./modules/authentication').init(app, config);
  // Replace the isAuthenticated with the one setup on passport module
  isAuthenticated = passport.authenticationMiddleware
    ? passport.authenticationMiddleware
    : isAuthenticated;
} else if (config.enableAuthentication && !config.enableHttps) {
  console.error(
    'Trying to use authentication without using HTTPS, this is not allowed and so authentication will NOT be turned on, please turn on HTTPS to turn on authentication'
  );
}

//Setup the login page if we are using authentication
if (config.enableAuthentication) {
	app.get('/login', function (req, res) {
		res.sendFile(__dirname + '/login.html');
	});

	// create application/x-www-form-urlencoded parser
	var urlencodedParser = bodyParser.urlencoded({ extended: false });
  
	//login page form data is posted here
	app.post(
	  '/login',
	  urlencodedParser,
	  passport.authenticate('local', { failureRedirect: '/login' }),
	  function (req, res) {
		//On success try to redirect to the page that they originally tired to get to, default to '/' if no redirect was found
		var redirectTo = req.session.redirectTo
		  ? req.session.redirectTo
		  : '/';
		delete req.session.redirectTo;
		console.log(`Redirecting to: '${redirectTo}'`);
		res.redirect(redirectTo);
	  }
	);
  
	app.get('/logout', function (req, res) {
	  req.logout();
	  res.sendFile(__dirname + '/login.html');
	});
}
///////////////////////////////////////////////////////////////////////////


// No servers are available so send some simple JavaScript to the client to make
// it retry after a short period of time.
function sendRetryResponse(res) {
	res.sendFile(__dirname + "/status.htm");
}

// Get a Cirrus server if there is one available which has no clients connected.
function getAvailableCirrusServer() {
	for (cirrusServer of cirrusServers.values()) {
		console.log(`Checking for ${cirrusServer.address}:${cirrusServer.port} with clientConnected ${cirrusServer.numConnectedClients}`);
		if (cirrusServer.numConnectedClients === 0 && cirrusServer.ready === true) {

			//////////////////////////// MSFT Improvement  ////////////////////////////
			// Check if we had at least 45 seconds since the last redirect, avoiding the
			// chance of redirecting 2+ users to the same SS before they click Play.
			if( cirrusServer.lastRedirect ) {
				if( ((Date.now() - cirrusServer.lastRedirect) / 1000) < 45 ) {
					console.log(`lastRedirect was less than 45 seconds so ignoring this server with the difference ${(Date.now() - cirrusServer.lastRedirect) / 1000}`);
					continue;
				}
			}
			cirrusServer.lastRedirect = Date.now();
			///////////////////////////////////////////////////////////////////////////

			return cirrusServer;
		}
	}

	console.log('WARNING: No empty Cirrus servers are available');
	return undefined;
}

if(enableRESTAPI) {
	// Handle REST signalling server only request.
	app.options('/signallingserver', cors())
	app.get('/signallingserver', cors(),  (req, res) => {
		cirrusServer = getAvailableCirrusServer();
		if (cirrusServer != undefined) {
			res.json({ signallingServer: `${cirrusServer.address}:${cirrusServer.port}`});
			console.log(`Returning ${cirrusServer.address}:${cirrusServer.port}`);
		} else {
			res.json({ signallingServer: '', error: 'No signalling servers available'});
		}
	});
}

var parseDomain = require('@7c/parsedomain');

// Set cookies if using authentication, to ensure users can't get to SS without MM auth
function setAuthenticationCookie(req, res) {
	try {
		var hostUrl = req.headers.host;
		const { fulldomain, hostname, domain, tld } = parseDomain(hostUrl);
		var fullUrl = req.protocol + '://' + req.get('host') + req.originalUrl;
		res.cookie('mm_address', fullUrl, { maxAge: 2592000000, httpOnly: true, domain: fulldomain});
		
		// If authentication enabled, set a cookie before redirecting so SS can check authentication
		if (config.enableAuthentication) {
			console.log(`COOKIE: Domain for shared cookie: ${fulldomain}`)
			
			// Set cookie for SS to check if authenticated from MM
			res.cookie('mm_authenticated', 'true', { maxAge: config.authCookieExpirationMaxAge, httpOnly: true, domain: fulldomain});
		}
	} catch(e) {
		console.log(`ERROR (${e.toString()}): Issue with parsing domain and cookie creation`);
		ai.logError(e);
	}
}

if(enableRedirectionLinks) {
	// Handle standard URL.
	app.get('/', isAuthenticated('/login'), function (req, res) {
		cirrusServer = getAvailableCirrusServer();
		if (cirrusServer != undefined) {
			
			setAuthenticationCookie(req, res);

			console.log(`Redirect to ${cirrusServer.enableHttps ? 'https' : 'http' }://${cirrusServer.address}:${cirrusServer.port}`);
			res.redirect(`${cirrusServer.enableHttps ? 'https' : 'http' }://${cirrusServer.address}:${cirrusServer.port}/`);
		} else {
			sendRetryResponse(res);
		}
	});

	// Handle URL with custom HTML.
	app.get('/custom_html/:htmlFilename', (req, res) => {
		cirrusServer = getAvailableCirrusServer();
		if (cirrusServer != undefined) {
			
			setAuthenticationCookie(req, res);

			console.log(`Redirect to ${cirrusServer.enableHttps ? 'https' : 'http' }://${cirrusServer.address}:${cirrusServer.port}`);
			res.redirect(`${cirrusServer.enableHttps ? 'https' : 'http' }://${cirrusServer.address}:${cirrusServer.port}/custom_html/${req.params.htmlFilename}`);
		} else {
			sendRetryResponse(res);
		}
	});
}

//
// Connection to Cirrus.
//

const net = require('net');

function disconnect(connection) {
	console.log(`Ending connection to remote address ${connection.remoteAddress}`);
	connection.end();
}

const matchmaker = net.createServer((connection) => {
	connection.on('data', (data) => {
		try {
			message = JSON.parse(data);

			if(message)
				console.log(`Message TYPE: ${message.type}`);
		} catch(e) {
			console.log(`ERROR (${e.toString()}): Failed to parse Cirrus information from data: ${data.toString()}`);
			disconnect(connection);
			ai.logError(e);   //////// AZURE ////////
			return;
		}
		if (message.type === 'connect') {
			// A Cirrus server connects to this Matchmaker server.
			cirrusServer = {
				address: message.address,
				port: message.port,
				numConnectedClients: 0,
				lastPingReceived: Date.now(),
				version: message.version,
				enableHttps: message.enableHttps
			};
			cirrusServer.ready = message.ready === true;

			//////////////////////////// MSFT Improvement  ////////////////////////////
			// Handles disconnects between MM and SS to not add dupes with numConnectedClients = 0 and redirect users to same SS
			// Check if player is connected and doing a reconnect. message.playerConnected is a new variable sent from the SS to
			// help track whether or not a player is already connected when a 'connect' message is sent (i.e., reconnect).
			if(message.playerConnected == true) {
				cirrusServer.numConnectedClients = 1;
			}

			// Find if we already have a ciruss server address connected to (possibly a reconnect happening)
			let server = [...cirrusServers.entries()].find(([key, val]) => val.address === cirrusServer.address && val.port === cirrusServer.port);

			// if a duplicate server with the same address isn't found -- add it to the map as an available server to send users to.
			if (!server || server.size <= 0) {
				console.log(`Adding connection for ${cirrusServer.address.split(".")[0]} with playerConnected: ${message.playerConnected} and version: ${message.version}`)
				cirrusServers.set(connection, cirrusServer);
            } else {
				console.log(`RECONNECT: cirrus server address ${cirrusServer.address.split(".")[0]} already found--replacing. playerConnected: ${message.playerConnected}`)
				var foundServer = cirrusServers.get(server[0]);

				// Make sure to retain the numConnectedClients from the last one before the reconnect to MM
				if (foundServer) {
					cirrusServers.set(connection, cirrusServer);
					console.log(`Replacing server with original with numConn: ${cirrusServer.numConnectedClients}`);
					cirrusServers.delete(server[0]);
				} else {
					cirrusServers.set(connection, cirrusServer);
					console.log("Connection not found in Map() -- adding a new one");
				}

				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("DuplicateCirrusConnection", 1);
				ai.logEvent("DuplicateCirrusConnection", message.address);
			}
			///////////////////////////////////////////////////////////////////////////

		} else if (message.type === 'streamerConnected') {
			// The stream connects to a Cirrus server and so is ready to be used
			console.log(`Message type streamerConnected received`)
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.ready = true;
				console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} ready for use`);

				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("StreamerConnected", 1);
				ai.logEvent("StreamerConnected", cirrusServer.address);
			} else {
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("CirrusServerUndefined", 1);
				ai.logEvent("CirrusServerUndefined", `No cirrus server found on streamer connect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else if (message.type === 'streamerDisconnected') {
			// The stream connects to a Cirrus server and so is ready to be used
			console.log(`Received request to streamerDisconnected from remote address ${connection.remoteAddress}`);
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.ready = false;
				console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} no longer ready for use`);
				
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("StreamerDisconnected", 1);
				ai.logEvent("StreamerDisconnected", cirrusServer.address);
				
			} else {
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("CirrusServerUndefined", 1);
				ai.logEvent("CirrusServerUndefined", `No cirrus server found on streamer disconnect: ${connection.remoteAddress}`);
				disconnect(connection);
			}
		} else if (message.type === 'clientConnected') {
			// A client connects to a Cirrus server.
			console.log(`Received request to connect to remote address ${connection.remoteAddress}`);
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				console.log(`Clients already connected to ${cirrusServer.address}:${cirrusServer.port} are ${cirrusServer.numConnectedClients}`);
				cirrusServer.numConnectedClients++;
				console.log(`Clients connection for ${cirrusServer.address}:${cirrusServer.port} increased to ${cirrusServer.numConnectedClients}`);

				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("ClientConnection", 1);
				ai.logEvent("ClientConnection", cirrusServer.address);
			} else {
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("CirrusServerUndefined", 1);
				ai.logEvent("CirrusServerUndefined", `No cirrus server found on client connect: ${connection.remoteAddress}`);

				disconnect(connection);
			}
		} else if (message.type === 'clientDisconnected') {
			// A client disconnects from a Cirrus server.
			console.log(`Received request to disconnect to remote address ${connection.remoteAddress}`);
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				console.log(`Clients already connected to ${cirrusServer.address}:${cirrusServer.port} are ${cirrusServer.numConnectedClients}`);
				if (cirrusServer.numConnectedClients > 0) { 
					cirrusServer.numConnectedClients--;
				}
				console.log(`Client connected to Cirrus server ${cirrusServer.address}:${cirrusServer.port} decreased to ${cirrusServer.numConnectedClients}`);
				
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("ClientDisconnected", 1);
				ai.logEvent("ClientDisconnected", cirrusServer.address);
				
			} else {
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("CirrusServerUndefined", 1);
				ai.logEvent("CirrusServerUndefined", `No cirrus server found on client disconnect: ${connection.remoteAddress}`);

				disconnect(connection);
			}
		} else if (message.type === 'ping') {
			cirrusServer = cirrusServers.get(connection);
			if(cirrusServer) {
				cirrusServer.lastPingReceived = Date.now();
			} else {
				/////////////////////////////// AZURE ///////////////////////////////
				ai.logMetric("CirrusServerUndefined", 1);
				ai.logEvent("CirrusServerUndefined", `No cirrus server found on client disconnect: ${connection.remoteAddress}`);

				disconnect(connection);
			}
		} else {
			console.log('ERROR: Unknown data: ' + JSON.stringify(message));
			disconnect(connection);

			/////////////////////////////// AZURE ///////////////////////////////
			ai.logMetric("MMBadMessageType", 1);
			ai.logEvent("MMBadMessageType", JSON.stringify(message));
		}

		/////////////////////////////// AZURE ///////////////////////////////
		// Use the Azure Module to evaluate whether or not we should scale/up down the VMSS compute for streams
		registerAndDoScaleEval();
	});

	// A Cirrus server disconnects from this Matchmaker server.
	connection.on('error', () => {
		cirrusServer = cirrusServers.get(connection);
		if(cirrusServer) {
			cirrusServers.delete(connection);
			console.log(`Cirrus server ${cirrusServer.address}:${cirrusServer.port} disconnected from Matchmaker`);

			/////////////////////////////// AZURE ///////////////////////////////
			ai.logEvent("MMCirrusDisconnect", `Cirrus server ${cirrusServer.address}:${cirrusServer.port} disconnected from Matchmaker`);
		} else {
			console.log(`Disconnected machine that wasn't a registered cirrus server, remote address: ${connection.remoteAddress}`);

			/////////////////////////////// AZURE ///////////////////////////////
			ai.logEvent("MMCirrusDisconnect", `Disconnected machine that wasn't a registered cirrus server, remote address: ${connection.remoteAddress}`);
		}

		/////////////////////////////// AZURE ///////////////////////////////
		ai.logMetric("MMCirrusDisconnect", 1);
	});
});

matchmaker.listen(config.matchmakerPort, () => {
	console.log('Matchmaker listening on *:' + config.matchmakerPort);
});

var scaleEvalRegistered = false;
function registerAndDoScaleEval()
{
	// situation can occur that scaling rules are ignored (scale process in progress)
	// therefore we register this Interval to do periodic checking if scaling is needed
	if(!scaleEvalRegistered) {
		scaleEvalRegistered = true;
		setInterval(function() {
			if (config.enableAutoScale) {
				autoscale.evaluateAutoScalePolicy(cirrusServers);
			} else {
				autoscale.getCurrentVMSSNodeCount().then((currentVMSSNodeCount) => {
					ai.logMetric("TotalInstances", currentVMSSNodeCount);
				});
			}
			connectionMgr.checkIfNodesAreStillResponsive(cirrusServers);
		}, config.scalingEvaluationInterval * 1000);
	}
}
