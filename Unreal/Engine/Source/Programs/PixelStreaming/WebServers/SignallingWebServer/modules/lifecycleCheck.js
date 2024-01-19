// Copyright Microsoft Corp. All Rights Reserved.

var config;
var ai;
var adminApiHttp;
var updateTriggered = false;

function initLifecycleCheckModule(configObj, aiObj) {

	console.log('init lifecycle module')
	config = configObj;
	ai = aiObj;
	adminApiHttp = require('http');

	// We only want to run the version-check on 1 of the Instances. 
	// So we check if we are on the first instance, otherwise we dont initiate the recurring task
	if(config.instanceNr == 1) { 
		var optionsget = {
			host : config.matchmakerInternalApiAddress,
			port : config.matchmakerInternalApiPort,
			path : '/api/settings/latestversion',
			method : 'GET'
		};

		setInterval(function() {
			var str = '';
			callback = function(response) {
				response.on('data', function (chunk) {
					str += chunk;
				});

				response.on('end', function () {
					try {
						var message = JSON.parse(str);

						console.log(`VERSION CHECK - Admin version: ${message.version} - This version: ${config.version}`);
						if(message.version > config.version)
						{
							triggerUpdate();
						}
					}
					catch(err) {
						console.log(err);
					}
				});
			}

			var req = adminApiHttp.request(optionsget, callback).end();
		}, 30 * 1000);
	}
}

async function getLatestSettings() {
	var optionsget = {
		host : config.matchmakerInternalApiAddress,
		port : config.matchmakerInternalApiPort,
		path : '/api/settings/latest',
		method : 'GET'
	};
	var str = '';

	return new Promise(function(resolve, reject) {
	  callback = function(response) {

		response.on('data', function (chunk) {
		  str += chunk;
		});
	  
		response.on('end', function () {
			try {
		 		var message = JSON.parse(str);
				resolve(message);
			} catch(err)
			{
				reject('Failed to parse response');
			}
		});

		response.on('error', function() {
			reject('Failed to make getLatestSettings request');
		});
	  }
	  
	  var req = adminApiHttp.request(optionsget, callback).end();
	});
}

function triggerUpdate() {
	if(!updateTriggered)
	{
		updateTriggered = true;
		console.log('start - triggerUpdate');
		
		getLatestSettings().then(function(newParams){
			try {
				ai.logEvent('UpdateTriggered', newParams.version);
				
				var spawn = require("child_process").spawn,child;
				child = spawn("powershell.exe",[`C:\\Unreal_${config.version}\\scripts\\mp_ss_update.ps1 -version ${newParams.version} -instancesPerNode ${newParams.instancesPerNode} -resolutionWidth ${newParams.resolutionWidth} -resolutionHeight ${newParams.resolutionHeight} -pixelstreamingApplicationName ${newParams.pixelstreamingApplicationName} -fps ${newParams.fps} -unrealApplicationDownloadUri "${newParams.unrealApplicationDownloadUri}" -stunServerAddress "${newParams.stunServerAddress}" -turnServerAddress "${newParams.turnServerAddress}" -turnUsername "${newParams.turnUsername}" -turnPassword "${newParams.turnPassword}"`]);
			
				child.stdout.on("data", function(data) {
					console.log("PowerShell Data: " + data);
				});
				child.stderr.on("data", function(data) {
					console.log("PowerShell Errors: " + data);
				});
				child.on("exit",function(){
					console.log("The PowerShell script complete.");
				});
				child.stdin.end();
			} catch(e) {
				console.log(`ERROR: Errors executing PowerShell with message: ${e.toString()}`);
			}
		}).catch(function(e) {
			console.log(`ERROR: Error fetching Latest Versions: ${e.toString()} - retrying.`);
			// update has failed, so retry by setting the updateTriggered var to false
			updateTriggered = false;
		});
	}
}

module.exports = {
	init: initLifecycleCheckModule,
	triggerUpdate
}