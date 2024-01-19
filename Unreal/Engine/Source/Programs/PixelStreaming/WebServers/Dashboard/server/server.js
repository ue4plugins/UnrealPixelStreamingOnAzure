const express = require("express");
const path = require("path");
const app = express();
const userLayer = require("./modules/userLayer.js");

const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault-secrets");

const credential = new DefaultAzureCredential();

// Build the URL to reach your key vault
const url = `https://${process.env.KEYVAULTNAME}.vault.azure.net`;

// Lastly, create our secrets client and connect to the service
const client = new SecretClient(url, credential);

var appInsightsSettings = {};

client.getSecret("appInsightsApplicationId").then(function (response) {
  var appInsightsApplicationId = response.value;

  client.getSecret("appInsightsApiKey").then(function (response) {
    var appInsightsApiKey = response.value;

    appInsightsSettings = {
      appInsightsApplicationId: appInsightsApplicationId,
      appInsightsApiKey: appInsightsApiKey,
    };

    const api = require("./modules/api.js");
    api.init(app, appInsightsSettings);

    app.use(express.static(path.join(__dirname, "build")));

    app.get("/api/user", function (req, res) {
      const token = req.header("x-ms-client-principal");
      try {
        const usrObj = userLayer.parseToken(token);
        const claims = userLayer.getClaims(usrObj);
        const userInfo = {
          family_name:
            claims[
              "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
            ],
          given_name:
            claims[
              "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
            ],
          email:
            claims[
              "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
            ],
          name: claims["name"],
        };

        res.status(200).json(userInfo);
      } catch (err) {
        res.status(400).send("There was a problem getting the user info.");
      }
    });

    app.get("*", function (req, res) {
      res.sendFile(path.join(__dirname, "build", "index.html"));
    });

    // set port, listen for requests
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}.`);
    });
  });
});
