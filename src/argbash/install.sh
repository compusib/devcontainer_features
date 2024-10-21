set -e




ARGBASH_VERSION=${VERSION:-"2.10.0"}
ARGBASH_PREFIX=${INSTALLPREFIX:-/usr/local}

mkdir /tmp/argbash
cd /tmp/argbash

wget https://github.com/matejak/argbash/archive/refs/tags/${ARGBASH_VERSION}.tar.gz
tar -xzf $ARGBASH_VERSION.tar.gz
cd argbash-$ARGBASH_VERSION/resources

make install PREFIX=$ARGBASH_PREFIX
rm -rf /tmp/argbash

echo 'Done!'
