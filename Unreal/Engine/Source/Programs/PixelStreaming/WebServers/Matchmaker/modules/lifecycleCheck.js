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
				} catch(err) {
					console.log(err);
				}
            });
        }

        var req = adminApiHttp.request(optionsget, callback).end();
    }, 30 * 1000);
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
			} catch(err) {
				reject(err);
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
				child = spawn("powershell.exe",[`C:\\Unreal_${config.version}\\scripts\\mp_mm_update.ps1 ${newParams.version} ${newParams.instancesPerNode} ${newParams.enableAutoScale} ${newParams.instanceCountBuffer} ${newParams.percentBuffer} ${newParams.minMinutesBetweenScaledowns} ${newParams.scaleDownByAmount} ${newParams.minInstanceCount} ${newParams.maxInstanceCount} "${newParams.unrealApplicationDownloadUri}"`]);
			
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
				// update has failed, so retry by setting the updateTriggered var to false
				updateTriggered = false;
			}
		});
	}
}

module.exports = {
	init: initLifecycleCheckModule,
	triggerUpdate
}