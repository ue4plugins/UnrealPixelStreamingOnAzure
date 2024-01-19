import { ActionButton } from "@fluentui/react";
import { useEffect, useState } from "react";
import { useHistory } from "react-router-dom";
import { Config, getConfig } from "src/api";

const routes = [
  { label: "Home", iconName: "Home", routePath: "/" },
  { label: "Settings", iconName: "Settings", routePath: "/settings" },
  { label: "Accounts", iconName: "AccountManagement", routePath: "/accounts" },
];

const Nav = () => {
  const history = useHistory();
  const [config, setConfig] = useState<Config>({});

  const filteredRoutes = routes.filter(
    (r) => config.enableAuthentication || r.label !== "Accounts"
  );

  const goToPage = (route: string) => {
    history.push(route);
  };

  useEffect(() => {
    getConfig().then((response) => setConfig(response || {}));
  }, []);

  return (
    <div
      style={{
        height: "100%",
        width: 200,
        boxShadow: "0 0 28px rgba(0, 0, 0, 0.07)",
      }}
    >
      <ul
        style={{
          listStyle: "none",
          margin: 0,
          paddingLeft: 0,
          paddingTop: 20,
        }}
      >
        {filteredRoutes.map((r) => (
          <li
            key={`page-${r.label}`}
            style={{ paddingLeft: 10, paddingRight: 10 }}
          >
            <ActionButton
              iconProps={{ iconName: r.iconName }}
              onClick={goToPage.bind(this, r.routePath)}
            >
              {r.label}
            </ActionButton>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default Nav;
