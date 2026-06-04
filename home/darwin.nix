{ pkgs, ... }:
{
  home.packages = with pkgs; [
    colima          # Linux VM that runs the Docker daemon on macOS
    docker-client   # CLI only (daemon runs in colima)
    docker-compose
    ghostty
    rectangle
  ];
}
