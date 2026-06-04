{ pkgs, ... }:
{
  home.packages = with pkgs; [
    docker          # full daemon + CLI
    docker-compose
  ];
}
