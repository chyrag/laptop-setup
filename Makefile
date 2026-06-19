.PHONY: bootstrap setup switch build update diff rollback help test test-clean _test-multipass _test-virtinstall

PROFILE    := default
HM_PROFILE := $(HOME)/.local/state/nix/profiles/home-manager
# Shell prompt theme: "starship" (default) or "ohmyzsh"
SHELL_THEME ?= starship

# Test VM settings
VM_NAME    := laptop-test
# Debian 12 nocloud image: no cloud-init, DHCP pre-configured, root SSH login enabled.
# guestfish injects the host SSH key before first boot — no metadata server needed.
DEBIAN_IMG_URL := https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2
DEBIAN_IMG     := /var/lib/libvirt/images/debian-12-nocloud-amd64.qcow2
VM_DISK        := /var/lib/libvirt/images/$(VM_NAME).qcow2

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

help:
	@echo "Usage: make [target] [SHELL_THEME=starship|ohmyzsh]"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap   Run the full bootstrap script on a new machine (Nix path)"
	@echo "  setup       Non-Nix setup: install packages via brew/apt and copy dotfiles"
	@echo "  switch      Apply home-manager config to the current user"
	@echo "  build       Build config without applying (dry run)"
	@echo "  update      Update flake inputs (nixpkgs etc.) then switch"
	@echo "  diff        Show package diff between current and new config"
	@echo "  rollback    Roll back to the previous home-manager generation"
	@echo "  test        Spin up a test VM (multipass on macOS/Ubuntu, virt-install on Debian)"
	@echo "  test-clean  Destroy the test VM"
	@echo ""
	@echo "Variables:"
	@echo "  SHELL_THEME   starship (default) or ohmyzsh"
	@echo ""
	@echo "Required env for switch/build/update/diff:"
	@echo "  GIT_USER_NAME   Your git display name"
	@echo "  GIT_USER_EMAIL  Your git email"

bootstrap:
	@./scripts/bootstrap.sh

setup:
	@./scripts/setup.sh

switch: guard-git-env
	SHELL_THEME=$(SHELL_THEME) home-manager switch --flake .#$(PROFILE) --impure

build: guard-git-env
	SHELL_THEME=$(SHELL_THEME) home-manager build --flake .#$(PROFILE) --impure

update: guard-git-env
	nix flake update
	$(MAKE) switch

diff: guard-git-env
	home-manager build --flake .#$(PROFILE) --impure
	nix run nixpkgs#nvd -- diff $(HM_PROFILE) result

rollback:
	home-manager rollback

# Dispatches to multipass (macOS / Ubuntu) or virt-install (Debian / other Linux).
# Inside the VM, run:
#   export GIT_USER_NAME='...' GIT_USER_EMAIL='...'
#   cd ~/laptop-setup && ./scripts/bootstrap.sh
test:
	@if command -v multipass >/dev/null 2>&1; then \
		$(MAKE) _test-multipass; \
	elif command -v virt-install >/dev/null 2>&1; then \
		$(MAKE) _test-virtinstall; \
	else \
		echo ""; \
		echo "Error: no VM tool found. Install one of:"; \
		echo "  Ubuntu/macOS : sudo snap install multipass"; \
		echo "  Debian       : sudo apt install virtinst qemu-kvm libvirt-daemon-system cloud-image-utils"; \
		echo ""; \
		exit 1; \
	fi

_test-multipass:
	@echo "==> Removing any existing test VM..."
	-multipass delete $(VM_NAME) --purge 2>/dev/null || true
	@echo "==> Creating fresh Ubuntu 24.04 VM (2 CPU, 4G RAM, 20G disk)..."
	multipass launch 24.04 -n $(VM_NAME) --cpus 2 --memory 4G --disk 20G
	@echo "==> Mounting repo at ~/laptop-setup..."
	multipass mount "$(CURDIR)" $(VM_NAME):/home/ubuntu/laptop-setup
	@echo ""
	@echo "Inside the VM, run:"
	@echo "  export GIT_USER_NAME='Your Name' GIT_USER_EMAIL='you@example.com'"
	@echo "  cd ~/laptop-setup && ./scripts/bootstrap.sh"
	@echo ""
	multipass shell $(VM_NAME)

_test-virtinstall:
	@echo "==> Destroying any existing test VM..."
	-sudo virsh destroy  $(VM_NAME) 2>/dev/null || true
	-sudo virsh undefine $(VM_NAME) --remove-all-storage 2>/dev/null || true
	@echo "==> Fetching Debian 12 cloud image (skipped if already cached)..."
	@if [ ! -f $(DEBIAN_IMG) ]; then \
		sudo wget -O $(DEBIAN_IMG) $(DEBIAN_IMG_URL); \
	fi
	@echo "==> Creating VM disk (20G, root partition expanded)..."
	sudo qemu-img create -f qcow2 $(VM_DISK) 20G
	sudo virt-resize --expand /dev/sda1 $(DEBIAN_IMG) $(VM_DISK)
	@echo "==> Installing sshd and injecting SSH key into disk image..."
	@KEYFILE=$$(ls ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null | head -1); \
	sudo virt-customize -a $(VM_DISK) \
		--install openssh-server,rsync \
		--run-command 'systemctl enable ssh' \
		--ssh-inject root:file:$$KEYFILE
	@echo "==> Ensuring libvirt default network is active..."
	@if ! sudo virsh net-info default 2>/dev/null | grep -q "Name:"; then \
		echo "  Defining default NAT network..."; \
		NETXML=$$(mktemp --suffix=.xml); \
		printf '<network><name>default</name><forward mode="nat"/><bridge name="virbr0" stp="on" delay="0"/><ip address="192.168.122.1" netmask="255.255.255.0"><dhcp><range start="192.168.122.2" end="192.168.122.254"/></dhcp></ip></network>\n' > $$NETXML; \
		sudo virsh net-define $$NETXML; \
		rm -f $$NETXML; \
	fi
	@sudo virsh net-start default 2>/dev/null || true
	@sudo virsh net-autostart default 2>/dev/null || true
	@echo "==> Booting VM via virt-install..."
	sudo virt-install \
		--name        $(VM_NAME) \
		--memory      4096 \
		--vcpus       2 \
		--disk        path=$(VM_DISK),format=qcow2 \
		--os-variant  debian12 \
		--network     network=default \
		--graphics    none \
		--noautoconsole \
		--import
	@echo "==> Waiting for VM to get an IP..."; \
	until sudo virsh domifaddr $(VM_NAME) --source arp 2>/dev/null | grep -q ipv4; do sleep 2; done; \
	VM_IP=$$(sudo virsh domifaddr $(VM_NAME) --source arp | awk '/ipv4/{gsub("/.*","",$$4); print $$4}'); \
	echo "==> VM IP: $$VM_IP"; \
	echo "==> Waiting for SSH..."; \
	until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 root@$$VM_IP true 2>/dev/null; do sleep 3; done; \
	echo "==> Copying repo into VM..."; \
	rsync -az --exclude='.git/' --exclude='.vagrant/' --exclude='result' \
		"$(CURDIR)/" root@$$VM_IP:~/laptop-setup/; \
	echo ""; \
	echo "==> SSH into the VM with:"; \
	echo "  ssh root@$$VM_IP"; \
	echo ""; \
	echo "Inside the VM, run:"; \
	echo "  export GIT_USER_NAME='Your Name' GIT_USER_EMAIL='you@example.com'"; \
	echo "  cd ~/laptop-setup && ./scripts/bootstrap.sh"; \
	echo ""; \
	ssh -o StrictHostKeyChecking=no root@$$VM_IP

test-clean:
	-multipass delete $(VM_NAME) --purge 2>/dev/null || true
	-sudo virsh destroy  $(VM_NAME) 2>/dev/null || true
	-sudo virsh undefine $(VM_NAME) --remove-all-storage 2>/dev/null || true
	-sudo rm -f /var/lib/libvirt/images/$(VM_NAME).qcow2
