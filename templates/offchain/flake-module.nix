{ self, ... }:
{
  perSystem = { config, pkgs', self', inputs, system, ... }:
    let
      pkgs = import self.inputs.nixpkgs {
        inherit system;
      };
    in
    {
      offchain.default = {
        src = ./.;
        enableCtlServer = false;

        bundles = {
          web-bundle = {
            mainModule = "Main";
            browserRuntime = true;
            entrypointJs = "index.js";
            webpackConfig = "webpack.config.js";
            bundledModuleName = "output.js";
            enableCheck = true;
          };
        };

        shell = { };
        enableFormatCheck = true;
        enableJsLintCheck = true;

        plutip = {
          buildInputs = [ liqwid-scripts ];
          testMain = "PlutipTest";
        };

        tests = {
          testMain = "Test.Main";
        };
      };
    };
}
