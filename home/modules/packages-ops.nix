{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kubectl
    awscli2
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    azure-cli
    stern
    k9s
  ];
}
