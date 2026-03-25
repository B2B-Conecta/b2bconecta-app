# To learn more about how to use Nix to configure your environment
# see: https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  channel = "stable-24.11";
  packages = [
    pkgs.flutter
    pkgs.jdk17
  ];
  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart"
    ];
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "flutter";
        };
        android = {
          manager = "flutter";
        };
      };
    };
  };
}