#!/bin/sh
# Creates a self-signed code signing certificate, "Max Local Signing", in the login keychain.
# `make` signs with it when it exists, so macOS keeps Max's Accessibility access across builds
# (an ad-hoc signature changes with every build; a certificate's does not).
set -e
NAME="Max Local Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "\"$NAME\" already exists."
    exit 0
fi
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/cert.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days 3650 -config "$WORK/cert.cnf" 2>/dev/null
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/identity.p12" -passout pass:max -name "$NAME"
# -T lets codesign use the key without asking.
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P max -T /usr/bin/codesign
echo "Created \"$NAME\". Rebuild with make."
