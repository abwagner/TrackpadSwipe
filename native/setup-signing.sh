#!/bin/sh
# One local signing identity, isolated from the login/system keychains.
set -eu
task_state="$HOME/Library/Application Support/TrackpadTypeSigning"
task_keychain="$task_state/TrackpadType.keychain-db"
umask 077
mkdir -p "$task_state"
chmod 700 "$task_state"
if [ -f "$task_state/identity.sha1" ]; then
  printf 'Existing TrackpadType signing identity retained.\n'
  exit 0
fi
if [ -e "$task_keychain" ] && { [ ! -f "$task_state/signing-key.pem" ] || [ ! -f "$task_state/signing-cert.pem" ] || [ ! -f "$task_state/keychain-password" ]; }; then
  printf 'Incomplete signing setup lacks recovery material at %s.\n' "$task_state" >&2
  exit 1
fi
if [ ! -e "$task_keychain" ]; then
openssl rand -base64 32 > "$task_state/keychain-password"
# A config file works with both Apple's LibreSSL and OpenSSL; -addext does not.
cat > "$task_state/certificate.cnf" <<'EOF'
[req]
distinguished_name = subject
prompt = no
x509_extensions = signing
[subject]
CN = TrackpadType Local Development
[signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF
openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 \
  -config "$task_state/certificate.cnf" \
  -keyout "$task_state/signing-key.pem" -out "$task_state/signing-cert.pem" \
  2> "$task_state/setup.log"
task_password=$(cat "$task_state/keychain-password")
security create-keychain -p "$task_password" "$task_keychain"
fi
openssl pkcs12 -export -inkey "$task_state/signing-key.pem" \
  -in "$task_state/signing-cert.pem" -out "$task_state/identity.p12" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -passout "file:$task_state/keychain-password"
task_password=$(cat "$task_state/keychain-password")
security set-keychain-settings -lut 21600 "$task_keychain"
security unlock-keychain -p "$task_password" "$task_keychain"
security import "$task_state/identity.p12" -k "$task_keychain" \
  -P "$task_password" -T /usr/bin/codesign
security set-key-partition-list -S 'apple-tool:,apple:,codesign:' -s \
  -k "$task_password" "$task_keychain" > /dev/null
openssl x509 -in "$task_state/signing-cert.pem" -noout -fingerprint -sha1 \
  | sed 's/.*=//;s/://g' > "$task_state/identity.sha1"
# The private key now resides in the protected dedicated keychain.
rm "$task_state/signing-key.pem" "$task_state/identity.p12"
printf 'TrackpadType local signing identity created in %s\n' "$task_keychain"
