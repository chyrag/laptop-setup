.PHONY: bootstrap switch build update diff rollback

PROFILE := default
HM_PROFILE := $(HOME)/.local/state/nix/profiles/home-manager

# Require git identity for switch/build targets
guard-git-env:
	@if [ -z "$$GIT_USER_NAME" ] || [ -z "$$GIT_USER_EMAIL" ]; then \
		echo ""; \
		echo "Error: GIT_USER_NAME and GIT_USER_EMAIL must be exported."; \
		echo ""; \
		echo "  export GIT_USER_NAME='Your Name'"; \
		echo "  export GIT_USER_EMAIL='you@example.com'"; \
		echo "  make switch"; \
		echo ""; \
		exit 1; \
	fi

bootstrap:
	@./scripts/bootstrap.sh

switch: guard-git-env
	home-manager switch --flake .#$(PROFILE) --impure

build: guard-git-env
	home-manager build --flake .#$(PROFILE) --impure

update: guard-git-env
	nix flake update
	$(MAKE) switch

diff: guard-git-env
	home-manager build --flake .#$(PROFILE) --impure
	nix run nixpkgs#nvd -- diff $(HM_PROFILE) result

rollback:
	home-manager rollback
