import { Persona, PersonaInitialsColor, PersonaSize } from "@fluentui/react";
import { getInitials } from "@fluentui/utilities";
import { useEffect, useState } from "react";
import { AADUser, getUser } from "src/api";

export interface Setting {
  version?: number;
  instancesPerNode: number;
  resolutionWidth: number;
  resolutionHeight: number;
  fps: number;
  unrealApplicationDownloadUri: string;
  enableAutoScale?: boolean;
  instanceCountBuffer?: number;
  percentBuffer?: number;
  minMinutesBetweenScaledowns?: number;
  scaleDownByAmount?: number;
  minInstanceCount?: number;
  maxInstanceCount?: number;
  stunServerAddress: string;
  turnServerAddress: string;
  turnUsername: string;
  turnPassword: string;
}

const Header = () => {
  const [user, setUser] = useState<AADUser>();
  const initials = getInitials(user?.name || "", false);

  useEffect(() => {
    getUser().then(setUser);
  }, []);

  return (
    <div
      style={{
        backgroundColor: "#0078d4",
        color: "white",
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        height: 48,
        paddingLeft: 20,
        paddingRight: 20,
      }}
    >
      <img
        alt="Microsoft logo"
        src="./Microsoft-logo_rgb_c-wht.png"
        height={48}
      />
      <Persona
        imageInitials={initials}
        initialsColor={PersonaInitialsColor.darkGreen}
        size={PersonaSize.size32}
      />
    </div>
  );
};

export default Header;
