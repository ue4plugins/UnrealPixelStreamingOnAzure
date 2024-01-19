import { Stack } from "@fluentui/react";
import { BrowserRouter as Router, Route, Switch } from "react-router-dom";
import Accounts from "./containers/Accounts";
import Header from "./containers/Header";
import Home from "./containers/Home";
import Nav from "./containers/Nav";
import Settings from "./containers/Settings";

const App = () => {
  return (
    <Stack>
      <Stack styles={{ root: { height: "100vh" } }}>
        <Stack.Item>
          <Header />
        </Stack.Item>
        <Stack.Item grow={1}>
          <Router>
            <Stack horizontal={true} styles={{ root: { height: "100%" } }}>
              <Stack.Item styles={{ root: { height: "100%" } }}>
                <Nav />
              </Stack.Item>
              <Stack.Item grow={1}>
                <div
                  style={{
                    marginTop: 40,
                    display: "flex",
                    justifyContent: "center",
                  }}
                >
                  <div style={{ width: "80%" }}>
                    <Switch>
                      <Route exact path="/">
                        <Home />
                      </Route>
                      <Route path="/settings">
                        <Settings />
                      </Route>
                      <Route path="/accounts">
                        <Accounts />
                      </Route>
                    </Switch>
                  </div>
                </div>
              </Stack.Item>
            </Stack>
          </Router>
        </Stack.Item>
      </Stack>
    </Stack>
  );
};

export default App;
