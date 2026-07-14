{
  inputs = {
    devenv = {
      url = "github:cachix/devenv";
      inputs = {
        flake-parts.follows = "flake-parts";
        git-hooks.follows = "git-hooks";
        nixpkgs.follows = "nixpkgs";
      };
    };

    devlib = {
      url = "github:shikanime-studio/devlib";
      inputs = {
        devenv.follows = "devenv";
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        git-hooks.follows = "git-hooks";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://cachix.cachix.org"
      "https://devenv.cachix.org"
      "https://shikanime.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "shikanime.cachix.org-1:OrpjVTH6RzYf2R97IqcTWdLRejF6+XbpFNNZJxKG8Ts="
    ];
  };

  outputs =
    inputs@{
      devenv,
      devlib,
      flake-parts,
      git-hooks,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        devlib.flakeModule
        devenv.flakeModule
        git-hooks.flakeModule
        treefmt-nix.flakeModule
      ];
      perSystem =
        {
          lib,
          pkgs,
          ...
        }:
        with lib;
        {
          devenv = {
            modules = [
              {
                sops = {
                  enable = true;
                  settings =
                    let
                      # Workstations (Included in all environments)
                      telsha = "age17q5ljstyzkvqtejwfnyf5jvqduars2yauw7vtgu5fcf54tm2jf0sspvt3c";
                      nixtar = "age1x9v4ps90txy9mk4392uya93tyzx40te4dvns4chg5s6q8mfy03ns74jpay";
                      workstations = [
                        telsha
                        nixtar
                      ];

                      # Overlays mapping definition
                      overlays = [
                        {
                          name = "telsha";
                          keys = [
                            "age1eak84xcr44yfqsg843rfu2xajxsyvjwh67a630htpnd0scy7yu5szjfh8d"
                          ];
                        }
                        {
                          name = "nishir";
                          keys = [
                            "age1f4yuh4j3gqafjduusfpxz3na9xtwth9s6gznq043mfex0zglp5jqkkdm64"
                          ];
                        }
                      ];

                      # Helper function to generate rules for a specific overlay environment
                      makeRulesForOverlay =
                        env:
                        let
                          keyGroup = [ { age = workstations ++ env.keys; } ];
                        in
                        [
                          {
                            path_regex = "apps/bazarr/overlays/${env.name}(.*)?/bazarr/config\\.enc\\.yaml";
                            encrypted_regex = "^(apikey|api_key|password|token|cookies|passkey|flask_secret_key|encryption_key|hashed_password|anti_captcha_key|gemini_key)$";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "apps/forgejo/overlays/${env.name}(.*)?/forgejo/app\\.enc\\.ini";
                            encrypted_regex = "^(PASSWD|SECRET_KEY|INTERNAL_TOKEN|LFS_JWT_SECRET|JWT_SECRET|PASSWORD)$";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "apps/hermes-agent/gateway/overlays/${env.name}(.*)?/hermes-agent-gateway-ssh/id_ed25519\\.enc\\.yaml";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "apps/synapse/overlays/${env.name}(.*)?/synapse/homeserver\\.enc\\.yaml";
                            encrypted_regex = "^(registration_shared_secret|form_secret|macaroon_secret_key)$";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "apps/mautrix/.+/overlays/${env.name}(.*)?/matrix-.+/config\\.enc\\.yaml";
                            encrypted_regex = "^(avatar_proxy_key|as_token|hs_token|pickle_key|server_key|shared_secret|signing_key|login_shared_secret_map|secrets)$";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "apps/mautrix/.+/overlays/${env.name}(.*)?/matrix-.+/(registration|doublepuppet)\\.enc\\.yaml";
                            encrypted_regex = "^(as_token|hs_token)$";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "(apps|configs|infrastructure)/.+/overlays/${env.name}(.*)?/.*\\.enc(\\..*)?";
                            key_groups = keyGroup;
                          }
                          {
                            path_regex = "clusters/${env.name}/overlays/.+/.*\\.enc(\\..*)?";
                            key_groups = keyGroup;
                          }
                        ];
                    in
                    {
                      creation_rules = concatMap makeRulesForOverlay overlays;
                    };
                };
              }
            ];
            shells.default = {
              imports = [
                devlib.devenvModules.git
                devlib.devenvModules.nix
                devlib.devenvModules.opentofu
                devlib.devenvModules.shell
                devlib.devenvModules.shikanime
              ];

              github.workflows.skaffold.enable = true;

              packages = [
                pkgs.age
                pkgs.caddy
                pkgs.clusterctl
                pkgs.docker
                pkgs.fluxcd
                pkgs.fluxcd-operator
                pkgs.gatekeeper
                pkgs.k0sctl
                pkgs.kubectl
                pkgs.kubernetes-helm
                pkgs.kustomize
                pkgs.ssh-to-age
                pkgs.skaffold
              ];

              tasks = {
                "manifests:kubeconform" = {
                  before = [ "devenv:enterTest" ];
                  exec = ''
                    for file in "$@"; do
                      ${pkgs.kustomize}/bin/kustomize build "$(dirname "$file")" | \
                        ${pkgs.kubeconform}/bin/kubeconform \
                          -exit-on-error \
                          -strict
                    done
                  '';
                };

                "manifests:bootstrap:telsha".exec = ''
                  ${getExe pkgs.kubectl} apply -k $DEVENV_ROOT/bootstraps/telsha

                  if ! ${getExe pkgs.kubectl} -n flux-system get secret sops-age >/dev/null 2>&1; then
                    ssh_key_file="/etc/ssh/ssh_host_ed25519_key"

                    sudo ${getExe pkgs.ssh-to-age} -private-key -i "$ssh_key_file" | \
                      ${getExe pkgs.kubectl} \
                        -n flux-system \
                        create secret generic sops-age \
                        --from-file=age.agekey=/dev/stdin
                  fi
                '';
              };

              treefmt.config.settings.global.excludes = [
                "*.excalidraw"
                "*.enc.xml"
              ];
            };
          };
        };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
}
