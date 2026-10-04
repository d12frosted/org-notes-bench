#!/usr/bin/env bash
# On the instance: mount the local NVMe disk at /mnt/bench, install what
# the tools use and build Emacs from source.
#
#   remote-setup.sh EMACS_VERSION STATE
set -euxo pipefail
EMACS_VERSION=$1
STATE=$2

# The instance store, not the EBS root (both are NVMe on Nitro)
DISK=$(lsblk -dpno NAME,MODEL | awk '/Instance Storage/ {print $1; exit}')
[ -n "$DISK" ] || { echo "no local instance storage found"; exit 1; }
sudo mkfs.ext4 -q -F "$DISK"
sudo mkdir -p /mnt/bench
sudo mount "$DISK" /mnt/bench
sudo chown ubuntu: /mnt/bench

sudo apt-get update -q
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
  build-essential libgccjit-13-dev libsqlite3-dev libgnutls28-dev libxml2-dev \
  libncurses-dev texinfo zlib1g-dev pkg-config curl git sqlite3 ripgrep fd-find fswatch
# Ubuntu names fd fdfind; the tools look for fd, as on macOS
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

cd /mnt/bench
curl -fsSLO "https://ftp.gnu.org/gnu/emacs/emacs-$EMACS_VERSION.tar.xz"
tar xf "emacs-$EMACS_VERSION.tar.xz"
cd "emacs-$EMACS_VERSION"
./configure -q --without-x --with-native-compilation=aot --with-sqlite3 \
  --without-pop --without-mailutils
make -s -j"$(nproc)"
sudo make -s install
emacs -Q --batch --eval '(unless (and (sqlite-available-p) (native-comp-available-p)) (kill-emacs 1))'

mkdir -p /mnt/bench/onb
tar -C /mnt/bench/onb -xzf ~/onb.tgz
tar -C /mnt/bench -xzf ~/trees.tgz
mkdir -p /mnt/bench/onb/results /mnt/bench/onb/data
if [ "$STATE" = tmpfs ]; then
  mkdir -p /dev/shm/state
  ln -sfn /dev/shm/state /mnt/bench/onb/data/state
fi
echo SETUP-OK
