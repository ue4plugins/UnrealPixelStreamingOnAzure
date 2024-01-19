// Copyright Epic Games, Inc. All Rights Reserved.

//-- Server side logic. Serves pixel streaming WebRTC-based page, proxies data back to Streamer --//

// Microsoft Notes: This file has additions to the Unreal Engine Matchmaker that were done in conjuction with Epic to
// add improved capabilities, resiliency and abilities to deploy and scale Pixel Streaming in Azure.
// "MSFT Improvement" -- Areas where Microsoft have added additional code to what is exported out of Unreal Engine
// "AZURE" -- Areas where Azure specific code was added (i.e., logging, metrics, etc.)

var express = require('express');
var cookieParser = require('cookie-parser');
var app = express();
app.use(cookieParser());

const fs = require('fs');
const path = require('path');
const querystring = require('querystring');
const bodyParser = require('body-parser');
const logging = require('./modules/logging.js');
logging.RegisterConsoleLogger();

// Command line argument --configFile needs to be checked before loading the config, all other command line arguments are dealt with through the config object

const defaultConfig = {
  UseFrontend: false,
  UseMatchmaker: false,
  enableHttps: false,
  enableAuthentication: false,
  LogToFile: true,
  HomepageFile: 'player.html',
  AdditionalRoutes: {},
  EnableWebserver: true,
  matchmakerAddress: "",
  matchmakerPort: "9999",
  publicIp: "localhost",
  HttpPort: 80,
  HttpsPort: 443,
  streamerPort: 8888,
  enableLifecycleManagement: false,
  signallingServerPort: 80,
  appInsightsInstrumentationKey: ""
};

const argv = require('yargs').argv;
var configFile =
  typeof argv.configFile != 'undefined'
    ? argv.configFile.toString()
    : path.join(__dirname, 'config.json');
console.log(`configFile ${configFile}`);
const config = require('./modules/config.js').init(configFile, defaultConfig);

if (config.LogToFile) {
  logging.RegisterFileLogger('./logs');
}

/////////////////////////////// AZURE ///////////////////////////////
// Add Azure Application Insights for logging / metrics
const ai = require('./modules/ai.js');
ai.init(config);
if (config.enableLifecycleManagement) {
  require('./modules/lifecycleCheck.js').init(config, ai);
}
/////////////////////////////////////////////////////////////////////

console.log('Config: ' + JSON.stringify(config, null, '\t'));

var http = require('http').Server(app);

if (config.enableHttps) {
  //HTTPS certificate details
  const options = {
    key: fs.readFileSync(
      path.join(__dirname, './certificates/client-key.pem')
    ),
    cert: fs.readFileSync(
      path.join(__dirname, './certificates/client-cert.pem')
    )
  };

  var https = require('https').Server(options, app);
}

//If not using authentication then just move on to the next function/middleware
var isAuthenticated = (redirectUrl) =>
  function (req, res, next) {
    return next();
  };

if (config.enableAuthentication && config.enableHttps && config.UseMatchmaker == false) {
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

const helmet = require('helmet');
var hsts = require('hsts');
var net = require('net');

var FRONTEND_WEBSERVER = 'https://localhost';
if (config.UseFrontend) {
  var httpPort = 3000;
  var httpsPort = 8000;

  //Required for self signed certs otherwise just get an error back when sending request to frontend see https://stackoverflow.com/a/35633993
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

  const httpsClient = require('./modules/httpsClient.js');
  var webRequest = new httpsClient();
} else {
  var httpPort = config.HttpPort;
  var httpsPort = config.HttpsPort;
}

var streamerPort = config.streamerPort; // port to listen to Streamer connections

var matchmakerAddress = '127.0.0.1';
var matchmakerPort = 9999;
var matchmakerRetryInterval = 5;
var matchmakerKeepAliveInterval = 30;

var gameSessionId;
var userSessionId;
var serverPublicIp;

// `clientConfig` is send to Streamer and Players
// Example of STUN server setting
// let clientConfig = {peerConnectionOptions: { 'iceServers': [{'urls': ['stun:34.250.222.95:19302']}] }};
var clientConfig = {
  type: "config",
  peerConnectionOptions: {},
  appInsightsInstrumentationKey: config.appInsightsInstrumentationKey,
  appInsightsMetricFlushInterval: config.appInsightsMetricFlushInterval
};

// Parse public server address from command line
// --publicIp <public address>
try {
  if (typeof config.publicIp != 'undefined') {
    serverPublicIp = config.publicIp.toString();
  }

  if (typeof config.HttpPort != 'undefined') {
    httpPort = config.HttpPort;
  }

  if (typeof config.HttpsPort != 'undefined') {
    httpsPort = config.HttpsPort;
  }

  if (typeof config.streamerPort != 'undefined') {
    streamerPort = config.streamerPort;
  }

  if (typeof config.FrontendUrl != 'undefined') {
    FRONTEND_WEBSERVER = config.FrontendUrl;
  }

  if(config.turnServerAddress != '' || config.stunServerAddress != '') {
    var conns = {
      iceServers: [
        {
          urls: [],
        }]
    }

	  if(config.stunServerAddress != '') conns.iceServers[0].urls.push(config.stunServerAddress);
	  if(config.turnServerAddress != '') conns.iceServers[0].urls.push(config.turnServerAddress);
	  if(config.turnUsername != '') conns.iceServers[0].username = config.turnUsername;
  	if(config.turnPassword != '') conns.iceServers[0].credential = config.turnPassword;

    //{ \""iceServers\"": [{\""urls\"": [\""stun:stun.l.google.com:19302\"",\""turn:" + $PublicIp + ":19303\""], \""username\"": \""{{{TURN_LOGIN}}}\"", \""credential\"": \""{{{TURN_PASSWORD}}}\""}] }
  
    clientConfig.peerConnectionOptions = conns;
    console.log(`peerConnectionOptions = ${JSON.stringify(clientConfig.peerConnectionOptions)}`);
  } else {
    console.log("No peerConnectionConfig");
  }

  if (typeof config.matchmakerAddress != 'undefined') {
    matchmakerAddress = config.matchmakerAddress;
  }

  if (typeof config.matchmakerPort != 'undefined') {
    matchmakerPort = config.matchmakerPort;
  }

  if (typeof config.MatchmakerRetryInterval != 'undefined') {
    matchmakerRetryInterval = config.MatchmakerRetryInterval;
  }
} catch (e) {
  console.error(e);

  /////////////////////////////// AZURE ///////////////////////////////
  ai.logMetric('SignalingServerError', 1);
  ai.logError(e);

  process.exit(2);
}

if (config.enableHttps) {
  app.use(helmet());

  app.use(hsts({
    maxAge: 15552000  // 180 days in seconds
  }));

  //Setup http -> https redirect
  console.log('Redirecting http->https');
  app.use(function (req, res, next) {
    if (!req.secure) {
      if (req.get('Host')) {
        var hostAddressParts = req.get('Host').split(':');
        var hostAddress = hostAddressParts[0];
        if (config.signallingServerPort != 443) {
          hostAddress = `${hostAddress}:${config.signallingServerPort}`;
        }
        return res.redirect(
          ['https://', hostAddress, req.originalUrl].join('')
        );
      } else {
        console.error(`unable to get host name from header. Requestor ${req.ip}, url path: '${req.originalUrl}', available headers ${JSON.stringify(req.headers)}`);
        return res.status(400).send('Bad Request');
      }
    }
    next();
  });
}

sendGameSessionData();

//Setup the login page if we are using authentication
if (config.enableAuthentication && config.UseMatchmaker == false) {
  if (config.EnableWebserver) {
    app.get('/login', function (req, res) {
      res.sendFile(__dirname + '/login.html');
    });
  }

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



if (config.EnableWebserver) {
  //Setup folders
  app.use(express.static(path.join(__dirname, '/public')));
  app.use('/images', express.static(path.join(__dirname, './images')));
  app.use('/scripts', [
    isAuthenticated('/login'),
    express.static(path.join(__dirname, '/scripts'))
  ]);
  app.use('/', [
    isAuthenticated('/login'),
    express.static(path.join(__dirname, '/custom_html'))
  ]);
}

try {
  for (var property in config.AdditionalRoutes) {
    if (config.AdditionalRoutes.hasOwnProperty(property)) {
      console.log(`Adding additional routes "${property}" -> "${config.AdditionalRoutes[property]}"`)
      app.use(property, [
        isAuthenticated('/login'),
        express.static(
          path.join(__dirname, config.AdditionalRoutes[property])
        )
      ]);
    }
  }
} catch (err) {
  console.error(`reading config.AdditionalRoutes: ${err}`);
}

if (config.EnableWebserver) {
  app.get('/', isAuthenticated('/login'), function (req, res) {

    /////////////////////////////// AZURE ///////////////////////////////

    // If using MM authentication, validate if we have a cookie from the MM, otherwise redirect
    // This ensures users can't share the SignalingServer URL, and must go through MM first for authentication.
    if (config.enableAuthentication && config.UseMatchmaker) {
        // Check for a valid cookie from the matchmaker if using authentication
        if(req.cookies && req.cookies.mm_authenticated) {
          console.log(`MM authentication found with value: ${req.cookies.mm_authenticated} `);
        } else {
          // If not authenticated and there are cookies, and there is a MM address that was passed over to the SS, redirect 
          if(req.cookies && req.cookies.mm_address) {
            console.log(`MM authentication not found, user tried to hit SS without MM login.`);
            return res.redirect(req.cookies.mm_address);
          } else {
            // Someone might have shared a link directly without going through MM -- send to 404
            console.log(`No cookies found from MM.`);
            return res.status(404).send('Not authenticated--please use the Matchmaker link.');
          }
        }       
    }

    /////////////////////////////// AZURE ///////////////////////////////


    homepageFile =
      (typeof config.HomepageFile != 'undefined' && config.HomepageFile != '')
        ? config.HomepageFile.toString()
        : defaultConfig.HomepageFile;
    homepageFilePath = path.join(__dirname, homepageFile);

    fs.access(homepageFilePath, (err) => {
      if (err) {
        console.error('Unable to locate file ' + homepageFilePath);
        res.status(404).send('Unable to locate file ' + homepageFile);
      } else {
        res.sendFile(homepageFilePath);
      }
    });
  });
}

//Setup http and https servers
if (!config.enableHttps) {
  http.listen(config.signallingServerPort, function () {
    console.logColor(
      logging.Green,
      'Http listening on *: ' + config.signallingServerPort
    );
  });
} else {
  https.listen(config.signallingServerPort, function () {
    console.logColor(
      logging.Green,
      'Https listening on *: ' + config.signallingServerPort
    );
  });
}

console.logColor(logging.Cyan, `Running Cirrus - The Pixel Streaming reference implementation signalling server for Unreal Engine 4.27.`);

/////////////////////////////////////////////////////////////////////////
// Create Websocket server for UE "streamer" to communicate with Cirrus.
/////////////////////////////////////////////////////////////////////////

let WebSocket = require('ws');

// let streamerServerOptions = !config.enableHttps ? {} : {
//   key: fs.readFileSync(path.join(__dirname, './certificates/client-key.pem')),
//   cert: fs.readFileSync(path.join(__dirname, './certificates/client-cert.pem')) //note this cert must be full chain (i.e. contain domain cert and CA cert)
// };

//var streamerHttpServer = require(config.enableHttps ? 'https' : 'http').Server(streamerServerOptions);
//streamerHttpServer.listen(streamerPort);
let streamerServer = new WebSocket.Server({ port: streamerPort, backlog: 1 });

console.log(`WebSocket listening to Streamer connections on :${streamerPort}`);
let streamer; // WebSocket connected to Streamer

streamerServer.on('connection', function (ws, req) {
  console.log(`Streamer connected: ${req.connection.remoteAddress}`);
  sendStreamerConnectedToMatchmaker();
  ai.logMetric('SSStreamerConnected', 1); //////// AZURE ////////

  ws.on('message', function onStreamerMessage(msg) {
    console.log(`<- Streamer: ${msg}`);

    try {
      msg = JSON.parse(msg);
    } catch (err) {
      console.error(`cannot parse Streamer message: ${msg}\nError: ${err}`);
      streamer.close(1008, 'Cannot parse');
      return;
    }

    try {
      if (msg.type == 'ping') {
        streamer.send(JSON.stringify({ type: 'pong', time: msg.time }));
        return;
      }

      let playerId = msg.playerId;
      delete msg.playerId; // no need to send it to the player

      // Convert incoming playerId to a string if it is an integer, if needed. (We support receiving it as an int or string).
      if (playerId && typeof playerId === 'number') {
        playerId = playerId.toString();
      }

      let player = players.get(playerId);
      console.log(`Player ID: ${playerId}`);
      if (!player) {
        console.log(
          `dropped message ${msg.type} as the player ${playerId} is not found`
        );
        return;
      }

      if (msg.type == 'answer') {
        player.ws.send(JSON.stringify(msg));
      } else if (msg.type == 'iceCandidate') {
        player.ws.send(JSON.stringify(msg));
      } else if (msg.type == 'disconnectPlayer') {
        player.ws.close(1011 /* internal error */, msg.reason);
      } else {
        console.error(`unsupported Streamer message type: ${msg.type}`);
        streamer.close(1008, 'Unsupported message type');
      }
    } catch (err) {
      console.error(`ERROR: ws.on message error: ${err.message}`);
    }
  });

  function onStreamerDisconnected() {
    sendStreamerDisconnectedToMatchmaker();
    disconnectAllPlayers();
    ai.logMetric('SSStreamerDisconnected', 1); //////// AZURE ////////
  }

  ws.on('close', function (code, reason) {
    try {
      console.error(`streamer disconnected: ${code} - ${reason}`);
      onStreamerDisconnected();
    } catch (err) {
      console.error(`ERROR: ws.on close error: ${err.message}`);
    }
  });

  ws.on('error', function (error) {
    try {
      console.error(`streamer connection error: ${error}`);
      ws.close(1006 /* abnormal closure */, error);
      onStreamerDisconnected();
    } catch (err) {
      console.error(`ERROR: ws.on error: ${err.message}`);
    }
  });

  streamer = ws;

  streamer.send(JSON.stringify(clientConfig));
});

//////////////////////////////////////////////////////////////////////////////
// Create Websocket server for players (browsers) to communicate with Cirrus.
//////////////////////////////////////////////////////////////////////////////

let playerServer = new WebSocket.Server({
  server: config.enableHttps ? https : http,
});
console.log(
  `WebSocket listening to Players connections on :${config.signallingServerPort}`
);

let players = new Map(); // playerId <-> player, where player is either a web-browser or a native webrtc player
let nextPlayerId = 100;

playerServer.on('connection', function (ws, req) {
  // Reject connection if streamer is not connected
  if (!streamer || streamer.readyState != 1 /* OPEN */) {
    ws.close(1013 /* Try again later */, 'Streamer is not connected');
    return;
  }

  let playerId = (++nextPlayerId).toString();
  console.log(
    `player ${playerId} (${req.connection.remoteAddress}: (${req.connection.remotePort}) connected`
  );
  players.set(playerId, { ws: ws, id: playerId });
  ai.logMetric('SSPlayerConnected', 1); //////// AZURE ////////

  function sendPlayersCount() {
    let playerCountMsg = JSON.stringify({
      type: 'playerCount',
      count: players.size,
    });
    for (let p of players.values()) {
      p.ws.send(playerCountMsg);
    }
  }

  ws.on('message', function (msg) {
    console.logColor(logging.Blue, `<- player ${playerId}: ${msg}`);

    try {
      msg = JSON.parse(msg);
    } catch (err) {
      console.error(`Cannot parse player ${playerId} message: ${err}`);
      ws.close(1008, 'Cannot parse');

      /////////////////////////////// AZURE ///////////////////////////////
      ai.logMetric('SignalingServerError', 1);
      ai.logError(err);

      return;
    }

    if (msg.type == 'offer') {
      console.log(`<- player ${playerId}: offer`);
      msg.playerId = playerId;
      streamer.send(JSON.stringify(msg));
    } else if (msg.type == 'iceCandidate') {
      console.log(`<- player ${playerId}: iceCandidate`);
      msg.playerId = playerId;
      streamer.send(JSON.stringify(msg));
    } else if (msg.type == 'stats') {
      console.log(`<- player ${playerId}: stats\n${msg.data}`);
    } else if (msg.type == 'kick') {
      let playersCopy = new Map(players);
      for (let p of playersCopy.values()) {
        if (p.id != playerId) {
          console.log(`kicking player ${p.id}`);
          p.ws.close(4000, 'kicked');
        }
      }
    } else {
      console.error(
        `<- player ${playerId}: unsupported message type: ${msg.type}`
      );
      ws.close(1008, 'Unsupported message type');
      return;
    }
  });

  //////////////////////////// MSFT Improvement  ////////////////////////////
  // Added for the ability to restart the app once a user closes their session,
  // this way the next user doesn't see where the player last left off.
  // This calls a custom OnClientDisconnected.ps1 script to close and restart the app.
  function restartUnrealApp() {
    // Call the restart PowerShell script only if all players have disconnected
    if (players.size == 0) {
      try {
        var spawn = require('child_process').spawn,
          child;
        // TODO: Need to pass in a config path to this for more robustness and not hard coded
        child = spawn('powershell.exe', [
          `C:\\Unreal_${config.version}\\scripts\\OnClientDisconnected.ps1 ${config.unrealAppName} ${config.streamerPort}`,
        ]);

        child.stdout.on('data', function (data) {
          console.log('PowerShell Data: ' + data);
        });
        child.stderr.on('data', function (data) {
          console.log('PowerShell Errors: ' + data);
        });
        child.on('exit', function () {
          console.log('The PowerShell script complete.');
        });
        child.stdin.end();
      } catch (e) {
        console.log(
          `ERROR: Errors executing PowerShell with message: ${e.toString()}`
        );
        ai.logError(e); //////// AZURE ////////
      }
    }
  }
  ///////////////////////////////////////////////////////////////////////////

  function onPlayerDisconnected() {
    try {
      console.log('Handle onPlayerDisconnected event');
      players.delete(playerId);
      streamer.send(
        JSON.stringify({
          type: 'playerDisconnected',
          playerId: playerId,
        })
      );
      sendPlayerDisconnectedToFrontend();
      sendPlayerDisconnectedToMatchmaker();
      sendPlayersCount();
      console.log('Ending handling of onPlayerDisconnected event');

      ai.logMetric('SSPlayerDisconnected', 1); //////// AZURE ////////
    } catch (err) {
      console.logColor(
        logging.Red,
        `ERROR:: onPlayerDisconnected error: ${err.message}`
      );
    }
  }

  ws.on('close', function (code, reason) {
    console.logColor(
      logging.Yellow,
      `player ${playerId} connection closed: ${code} - ${reason}`
    );
    onPlayerDisconnected();

    //////////////////////////// MSFT Improvement  ////////////////////////////
    // When a player session closes, kick off a restart for the Unreal app
    setTimeout(restartUnrealApp, 500);
    ///////////////////////////////////////////////////////////////////////////
  });

  ws.on('error', function (error) {
    console.error(`player ${playerId} connection error: ${error}`);
    ws.close(1006 /* abnormal closure */, error);
    onPlayerDisconnected();

    console.logColor(logging.Red, `Trying to reconnect...`);
    reconnect();
  });

  sendPlayerConnectedToFrontend();
  sendPlayerConnectedToMatchmaker();

  ws.send(JSON.stringify(clientConfig));

  sendPlayersCount();
});

function disconnectAllPlayers(code, reason) {
  let clone = new Map(players);
  for (let player of clone.values()) {
    player.ws.close(code, reason);
  }
}

/**
 * Function that handles the connection to the matchmaker.
 */

function safeWrite(socket, msg) {
  if (!socket.connecting) {
    socket.write(msg);
  }
}

if (config.UseMatchmaker) {
  var matchmaker = new net.Socket();

  matchmaker.on('connect', function () {
    console.log(
      `Cirrus connected to Matchmaker ${matchmakerAddress}:${matchmakerPort}`
    );

    //////////////////////////// MSFT Improvement  ////////////////////////////
    // message.playerConnected is a new variable sent from the SS to help track whether or not a player
    // is already connected when a 'connect' message is sent (i.e., reconnect). This happens when the MM
    // and the SS get disconnected unexpectedly (was happening often at scale for some reason).
    var playerConnected = false;

    // Set the playerConnected flag to tell the MM if there is already a player active (i.e., don't send a new one here)
    if (players && players.size > 0) {
      playerConnected = true;
    }

    // Add the new playerConnected flag to the message body to the MM
    message = {
      type: 'connect',
      address:
        typeof serverPublicIp === 'undefined'
          ? '127.0.0.1'
          : serverPublicIp,
      port: config.signallingServerPort,
      ready: streamer && streamer.readyState === 1,
      playerConnected: playerConnected,
      version: config.version,
      enableHttps: config.enableHttps
    };
    //////////////////////////// MSFT Improvement  ////////////////////////////

    safeWrite(matchmaker, JSON.stringify(message));
    ai.logMetric('SSMatchmakerConnected', 1); //////// AZURE ////////
  });

  matchmaker.on('error', (err) => {
    console.log(`Matchmaker connection error ${JSON.stringify(err)}`);
    ai.logMetric('SSMatchmakerConnectionError', 1); //////// AZURE ////////
  });

  matchmaker.on('end', () => {
    console.log('Matchmaker connection ended');
    ai.logMetric('SSMatchmakerConnectionEnded', 1); //////// AZURE ////////
  });

  matchmaker.on('close', (hadError) => {

    console.log(`Matchmaker connection closed (hadError=${hadError})`);
    matchmaker.setKeepAlive(true, 60000); // Keeps it alive for 60 seconds

    reconnect();
    ai.logMetric('SSMatchmakerConnectionClosed', 1); //////// AZURE ////////
  });

  // Attempt to connect to the Matchmaker
  function connect() {
    matchmaker.connect(matchmakerPort, matchmakerAddress);
  }

  // Try to reconnect to the Matchmaker after a given period of time
  function reconnect() {
    console.log(
      `Try reconnect to Matchmaker in ${matchmakerRetryInterval} seconds`
    );
    ai.logMetric('SSMatchmakerRetryConnection', 1); //////// AZURE ////////
    setTimeout(function () {
      connect();
    }, matchmakerRetryInterval * 1000);
  }

  function registerMMKeepAlive() {
    setInterval(function () {
      message = {
        type: 'ping',
      };
      // if the socket is in state 'connecting' we dont want to send this message. 
      // This happens when MM is down for instance for new version
      safeWrite(matchmaker, JSON.stringify(message));
    }, matchmakerKeepAliveInterval * 1000);
  }

  connect();
  registerMMKeepAlive();
}

//Keep trying to send gameSessionId in case the server isn't ready yet
function sendGameSessionData() {
  //If we are not using the frontend web server don't try and make requests to it
  if (!config.UseFrontend) return;

  webRequest.get(
    `${FRONTEND_WEBSERVER}/server/requestSessionId`,
    function (response, body) {
      if (response.statusCode === 200) {
        gameSessionId = body;
        console.log('SessionId: ' + gameSessionId);
      } else {
        console.error('Status code: ' + response.statusCode);
        console.error(body);
      }
    },
    function (err) {
      //Repeatedly try in cases where the connection timed out or never connected
      if (err.code === 'ECONNRESET') {
        //timeout
        sendGameSessionData();
      } else if (err.code === 'ECONNREFUSED') {
        console.error(
          'Frontend server not running, unable to setup game session'
        );
      } else {
        console.error(err);
      }
    }
  );
}

function sendUserSessionData(serverPort) {
  //If we are not using the frontend web server don't try and make requests to it
  if (!config.UseFrontend) return;

  webRequest.get(
    `${FRONTEND_WEBSERVER}/server/requestUserSessionId?gameSessionId=${gameSessionId}&serverPort=${serverPort}&appName=${querystring.escape(
      clientConfig.AppName
    )}&appDescription=${querystring.escape(clientConfig.AppDescription)}${typeof serverPublicIp === 'undefined'
      ? ''
      : '&serverHost=' + serverPublicIp
    }`,
    function (response, body) {
      if (response.statusCode === 410) {
        sendUserSessionData(serverPort);
      } else if (response.statusCode === 200) {
        userSessionId = body;
        console.log('UserSessionId: ' + userSessionId);
      } else {
        console.error('Status code: ' + response.statusCode);
        console.error(body);
      }
    },
    function (err) {
      //Repeatedly try in cases where the connection timed out or never connected
      if (err.code === 'ECONNRESET') {
        //timeout
        sendUserSessionData(serverPort);
      } else if (err.code === 'ECONNREFUSED') {
        console.error(
          'Frontend server not running, unable to setup user session'
        );
      } else {
        console.error(err);
      }
    }
  );
}

function sendServerDisconnect() {
  //If we are not using the frontend web server don't try and make requests to it
  if (!config.UseFrontend) return;

  try {
    webRequest.get(
      `${FRONTEND_WEBSERVER}/server/serverDisconnected?gameSessionId=${gameSessionId}&appName=${querystring.escape(
        clientConfig.AppName
      )}`,
      function (response, body) {
        if (response.statusCode === 200) {
          console.log('serverDisconnected acknowledged by Frontend');
        } else {
          console.error('Status code: ' + response.statusCode);
          console.error(body);
        }
      },
      function (err) {
        //Repeatedly try in cases where the connection timed out or never connected
        if (err.code === 'ECONNRESET') {
          //timeout
          sendServerDisconnect();
        } else if (err.code === 'ECONNREFUSED') {
          console.error(
            'Frontend server not running, unable to setup user session'
          );
        } else {
          console.error(err);
        }
      }
    );
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR::: sendServerDisconnect error: ${err.message}`
    );
  }
}

function sendPlayerConnectedToFrontend() {
  //If we are not using the frontend web server don't try and make requests to it
  if (!config.UseFrontend) return;

  try {
    webRequest.get(
      `${FRONTEND_WEBSERVER}/server/clientConnected?gameSessionId=${gameSessionId}&appName=${querystring.escape(
        clientConfig.AppName
      )}`,
      function (response, body) {
        if (response.statusCode === 200) {
          console.log('clientConnected acknowledged by Frontend');
        } else {
          console.error('Status code: ' + response.statusCode);
          console.error(body);
        }
      },
      function (err) {
        //Repeatedly try in cases where the connection timed out or never connected
        if (err.code === 'ECONNRESET') {
          //timeout
          sendPlayerConnectedToFrontend();
        } else if (err.code === 'ECONNREFUSED') {
          console.error(
            'Frontend server not running, unable to setup game session'
          );
        } else {
          console.error(err);
        }
      }
    );
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR::: sendPlayerConnectedToFrontend error: ${err.message}`
    );
  }
}

function sendPlayerDisconnectedToFrontend() {
  //If we are not using the frontend web server don't try and make requests to it
  if (!config.UseFrontend) return;
  try {
    webRequest.get(
      `${FRONTEND_WEBSERVER}/server/clientDisconnected?gameSessionId=${gameSessionId}&appName=${querystring.escape(
        clientConfig.AppName
      )}`,
      function (response, body) {
        if (response.statusCode === 200) {
          console.log('clientDisconnected acknowledged by Frontend');
          ai.logMetric('SSPlayerDisconnectedFrontEnd', 1); //////// AZURE ////////
        } else {
          console.error('Status code: ' + response.statusCode);
          console.error(body);
        }
      },
      function (err) {
        //Repeatedly try in cases where the connection timed out or never connected
        if (err.code === 'ECONNRESET') {
          //timeout
          sendPlayerDisconnectedToFrontend();
        } else if (err.code === 'ECONNREFUSED') {
          console.error(
            'Frontend server not running, unable to setup game session'
          );
        } else {
          console.error(err);
        }
      }
    );
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR::: sendPlayerDisconnectedToFrontend error: ${err.message}`
    );
  }
}

function sendStreamerConnectedToMatchmaker() {
  if (!config.UseMatchmaker) return;

  try {
    message = {
      type: 'streamerConnected',
    };
    safeWrite(matchmaker, JSON.stringify(message));
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR sending streamerConnected: ${err.message}`
    );
  }
}

function sendStreamerDisconnectedToMatchmaker() {
  if (!config.UseMatchmaker) {
    return;
  }

  try {
    message = {
      type: 'streamerDisconnected',
    };
    safeWrite(matchmaker, JSON.stringify(message));
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR sending streamerDisconnected: ${err.message}`
    );
  }
}

// The Matchmaker will not re-direct clients to this Cirrus server if any client
// is connected.
function sendPlayerConnectedToMatchmaker() {
  if (!config.UseMatchmaker) return;

  try {
    message = {
      type: 'clientConnected',
    };
    safeWrite(matchmaker, JSON.stringify(message));
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR sending clientConnected: ${err.message}`
    );
  }
}

// The Matchmaker is interested when nobody is connected to a Cirrus server
// because then it can re-direct clients to this re-cycled Cirrus server.
function sendPlayerDisconnectedToMatchmaker() {
  if (!config.UseMatchmaker) return;

  try {
    message = {
      type: 'clientDisconnected',
    };
    safeWrite(matchmaker, JSON.stringify(message));
  } catch (err) {
    console.logColor(
      logging.Red,
      `ERROR sending clientDisconnected: ${err.message}`
    );
  }
}
