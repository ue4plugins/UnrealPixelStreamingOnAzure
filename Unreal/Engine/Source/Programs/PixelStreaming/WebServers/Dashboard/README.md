# Getting Started

This dashboard was created using Create React App. The source code for the user interface is in the `src` folder.

## Running locally

1. Install node modules: `npm install`.
2. Set the AAD client ID or use the default in `config.json`.
3. Set the proxy to the deployed API in `package.json`. You'll need to update this with each new VM deployment.
4. Run the dashboard: `npm run start`.

## Creating a production build

To create a production build, run `npm run build`. This will create a `build` folder that can be referenced by the Matchmaker Node instance.
