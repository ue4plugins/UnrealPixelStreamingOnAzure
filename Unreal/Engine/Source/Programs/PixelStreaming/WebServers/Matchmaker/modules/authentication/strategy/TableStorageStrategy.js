const bcrypt = require("bcryptjs");
const http = require("http");
const passport = require("passport");
const LocalStrategy = require("passport-local").Strategy;

module.exports = (config) => {
  passport.use(
    new LocalStrategy((username, password, callback) => {
      const options = {
        host: config.matchmakerInternalApiAddress,
        port: config.matchmakerInternalApiPort,
        path: `/api/authuser/${username}`,
        method: "GET",
      };

      const req = http.request(options, (res) => {
        res.on("data", (user) => {
          const userObj = JSON.parse(user);
          bcrypt.compare(password, userObj.passwordHash, (err, isValid) => {
            if (err) {
              console.log(
                `Error comparing password for user '${username}': ${err}`
              );
              return callback(err);
            }

            if (!isValid) {
              console.log(`Password incorrect for user '${username}'`);
              return callback(null, false);
            }

            console.log(`User '${username}' logged in`);
            return callback(null, { username: user.username });
          });
        });
      });

      req.on("error", (err) => {
        return callback(err);
      });

      req.end();
    })
  );
};
