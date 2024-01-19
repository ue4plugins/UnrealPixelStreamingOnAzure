var ai;

function initConnectionManagerModule(aiObj){
	ai = aiObj;
}

function checkIfNodesAreStillResponsive(cirrusServers) {
	var threshold = 35;
	var brokenServers = [];
	var totalConnectedClients = 0;

	for (cirrusServer of cirrusServers.values()) {
		console.log(`SS CONNECTION CHECK - ${cirrusServer.address} pinged ${Math.round((Date.now() - cirrusServer.lastPingReceived)/1000)} ago`);
		if(Date.now() - cirrusServer.lastPingReceived > threshold*1000)
		{
			let server = [...cirrusServers.entries()].find(([key, val]) => val.address === cirrusServer.address && val.port === cirrusServer.port);
			brokenServers.push(server[0]);
		}
		else
		{
			totalConnectedClients += (cirrusServer.numConnectedClients > 1 ? 1 : cirrusServer.numConnectedClients);
		}
	}

	if(brokenServers.length > 0)
	{
		console.log(`${brokenServers.length} servers have been found that have not pinged the MM in the last ${threshold} seconds. Ending connection and removing from list.`);
		for(var i=0; i<brokenServers.length; i++) {
			var conn = brokenServers[i];
			ai.logEvent('Idle connection removed', `${conn.address}:${conn.port}`);

			var cirrusServer = cirrusServers.get(conn);
			cirrusServers.delete(conn);
			conn.end();
		}
	}

	// log stream and connection status
	const totalStreams = cirrusServers.size;
	const availableConnections = Math.max(totalStreams - totalConnectedClients, 0);
	var percentUtilized = 0;
	if (totalConnectedClients > 0 && totalStreams > 0) {
		percentUtilized = (totalConnectedClients / totalStreams) * 100;
	}

	ai.logMetric("TotalStreams", totalStreams);
	ai.logMetric("TotalConnectedClients", totalConnectedClients);
	ai.logMetric("PercentUtilized", percentUtilized);
	ai.logMetric("AvailableConnections", availableConnections);
}

module.exports = {
	init: initConnectionManagerModule,
	checkIfNodesAreStillResponsive
}