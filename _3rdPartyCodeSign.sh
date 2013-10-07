#/bin/bash

#  _3rdPartyCodeSign.sh
#
#
#  Created by Alexander Lehnert on 2012.11.07
#  Copyright (c) 2012 Boinx Software Ltd. All rights reserved.

#
# Use this script to resign existing Mach-O Files of 3rd-Party Frameworks that autoselect
# the wrong Code-Sign Identity
#

# Read the signing identiy from keychain
CODE_SIGN_CERTIFICATE=$(security find-identity -v | grep "\"${CODE_SIGN_IDENTITY}" | awk '{print $2}' | sed -e '2,$d')

echo "CONFIGURATION_BUILD_DIR: ${CONFIGURATION_BUILD_DIR}"
echo " Using singing Identity: ${CODE_SIGN_IDENTITY}: SH1=${CODE_SIGN_CERTIFICATE}"


#############################################################################################
# Apply a codesigning to a given file of app
# Argument $1 = path og Mach-o
# Argument $2 = optional arguments
#############################################################################################
function _resign_mach_o_file()
{
    local path="${1}"
    local entitlements="${2}"

    local workspace=$(pwd)
    local tmp="/tmp/$RANDOM"
    local tmp_entitlement="/tmp/$RANDOM"

    # extract entitlements from Binary
    local macho_entitlements=$(codesign --display --entitlements=- "${path}" 2>/dev/null)
    local macho_entitlements=${macho_entitlements##*<?xml}

    local entitlement_file=""

    # sing with entitlements
    if [[ "${macho_entitlements}" != "" ]]; then

        # save entitlement to file
        entitlement_file=$(basename "${path}")
        entitlement_file="${workspace}/${entitlement_file}.entitlement"

        # make valid XML file end export it
        macho_entitlements="<?xml${macho_entitlements}"

        codesign --force --verbose=2 --sign="${CODE_SIGN_CERTIFICATE}" --entitlements "${entitlement_file}" --timestamp=none --preserve-  metadata=i,res "${path}" 2>| $tmp

        $(rm -f "${entitlement_file}")

    # sign without entitlements
    else

        # use entitlement
        if [[ "${entitlements}" != "" ]]; then
            codesign --force --verbose=2 --sign="${CODE_SIGN_CERTIFICATE}" --entitlements "${entitlements}"  --timestamp=none --preserve-metadata=i,res "${path}" # 2>| $tmp
        #without entitlements
        else
            codesign --force --verbose=2 --sign="${CODE_SIGN_CERTIFICATE}" --timestamp=none --preserve-metadata=i,res "${path}" # 2>| $tmp
        fi
    fi
}
