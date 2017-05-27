#!/bin/bash

# Installs the specified Swift toolchain.
# Pass the full HTTPS toolchain download URL from swift.org
#
# Example: 
#   ./install_swift_toolchain.sh https://swift.org/builds/swift-4.0-branch/xcode/swift-4.0-DEVELOPMENT-SNAPSHOT-2017-05-24-a/swift-4.0-DEVELOPMENT-SNAPSHOT-2017-05-24-a-osx.pkg
#

####################################################
# Swift Toolchain PKG certificate SHA1 fingerprints
#
# Obtained via executing `pkgutil --check-signature`
# on a known-good swift toolchain .pkg

# 1. Developer ID Installer: Swift Open Source (V9AUD2URP3)
SWIFT_TOOLCHAIN_CERT_1="2F 17 A2 3F 0A 15 72 1B 71 C7 4D 35 40 F7 17 9B 58 11 67 9B"

# 2. Developer ID Certification Authority
SWIFT_TOOLCHAIN_CERT_2="3B 16 6C 3B 7D C4 B7 51 C9 FE 2A FA B9 13 56 41 E3 88 E1 86"

# 3. Apple Root CA
SWIFT_TOOLCHAIN_CERT_3="61 1E 5B 66 2C 59 3A 08 FF 58 D1 4A E2 24 52 D1 98 DF 6C 60"

####################################################

#set -e
#set -o xtrace

PKGUTIL=$(command -v pkgutil)
PLISTBUDDY=/usr/libexec/PlistBuddy

###########################
# Verify Input Parameters
###########################

if [ $# -eq 0 ]; then
    echo "No arguments supplied"
    echo "Pass the URL of the Swift toolchain to download as input."
    exit 1
fi

SWIFT_TOOLCHAIN_URL=$1


####################
# Download the PKG
####################

if ! TOOLCHAINPKG_DL_PATH=$(mktemp /tmp/toolchain-dl.XXXXXX); then
	echo "Failed to create temporary file."
	exit 1
fi

function finish {
  # Clean-up temporary download file
  rm -f $TOOLCHAINPKG_DL_PATH
}
trap finish EXIT

echo "Downloading Swift toolchain package:"
echo "   $SWIFT_TOOLCHAIN_URL"
echo "Destination: $TOOLCHAINPKG_DL_PATH"

if ! curl $SWIFT_TOOLCHAIN_URL -o $TOOLCHAINPKG_DL_PATH; then
	echo -e "curl failed - exiting."
	exit 1
fi

if ! mv $TOOLCHAINPKG_DL_PATH $TOOLCHAINPKG_DL_PATH.pkg; then
	echo "Failed to rename downloaded temporary file - exiting."
	exit 1
fi

TOOLCHAINPKG_DL_PATH+=.pkg
if [ ! -s $TOOLCHAINPKG_DL_PATH ]; then
	echo -e "Failed to download Swift toolchain from:\n   $SWIFT_TOOLCHAIN_URL"
	exit 1
fi

echo "Download complete."


#########################
# Verify Downloaded PKG
#########################

printf "Verifying Swift Toolchain signature..."

SIGNATURE=$($PKGUTIL --check-signature $TOOLCHAINPKG_DL_PATH)

# Verify that the downloaded pkg is signed by a trusted certificate
if ! grep -q 'Status: signed by a certificate trusted by Mac OS X' <<< $SIGNATURE > /dev/null; then
	printf " Failed.\n"
	echo -e "\n $SIGNATURE\n\n Downloaded PKG is not signed by a trusted certificate - exiting."
	exit 1
fi

CERT_FINGERPRINTS=$(grep 'SHA1 fingerprint:' <<< "$SIGNATURE")

# Verify the certificate fingerprints
certcount=1
trimprefix=' '
while read -r certificate_line; do
    input=SWIFT_TOOLCHAIN_CERT_$certcount
    expected=${!input}
    if ! certificate_tmp=$(cut -d':' -f2 <<< $certificate_line); then
	printf " Failed.\n"
	echo "Call to `cut` failed - exiting."
    fi
    current_certificate=${certificate_tmp#$trimprefix}
    if [ ! "$current_certificate" = "$expected" ]; then
	# Did not find expected certificate - Fail
	printf " Failed.\n"
	echo -e "Expected certificate ($expected)\n does not match found certificate: ($certcount): $current_certificate\n\n $SIGNATURE\n\n PKG signature validation failed - exiting."
	exit 1
    fi
    certcount=$((certcount + 1))
done <<< "$CERT_FINGERPRINTS"

printf " Succeeded.\n"


###################
# Install the PKG
###################

echo "Installing Swift Toolchain..."

sudo installer -pkg $TOOLCHAINPKG_DL_PATH -target /

echo "Swift Toolchain installation complete."

###########


#set +e