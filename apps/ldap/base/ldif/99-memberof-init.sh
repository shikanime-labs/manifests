#!/bin/bash
# Enable the memberOf overlay by modifying cn=config via ldapmodify.
# bitnami/openldap only executes .sh scripts from /docker-entrypoint-initdb.d/
# (slapd is stopped during this phase), so this script starts slapd,
# applies the overlay LDIF, and stops slapd.
#
# ponytail: idempotent — fails gracefully if the module or overlay already
# exists from a previous run or from the image defaults.
set -eo pipefail

export PATH="/opt/bitnami/openldap/bin:/opt/bitnami/openldap/sbin:${PATH}"

SLAPD_PID=""

cleanup() {
    if [[ -n "${SLAPD_PID}" ]] && kill -0 "${SLAPD_PID}" 2>/dev/null; then
        kill "${SLAPD_PID}" 2>/dev/null || true
        wait "${SLAPD_PID}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Start slapd temporarily for cn=config modifications
slapd -h "ldapi:/// " -F /opt/bitnami/openldap/etc/slapd.d -d 0 &
SLAPD_PID=$!
sleep 3

if ! kill -0 "${SLAPD_PID}" 2>/dev/null; then
    echo "ERROR: slapd failed to start" >&2
    exit 1
fi

# Apply the memberOf overlay LDIF from the custom bootstrap mount
MEMBEROF_LDIF="/container/service/slapd/assets/config/bootstrap/ldif/custom/30-memberof.ldif"
if [[ ! -f "${MEMBEROF_LDIF}" ]]; then
    # Fall back to the docker-entrypoint-initdb.d mount
    MEMBEROF_LDIF="/docker-entrypoint-initdb.d/30-memberof.ldif"
fi

if [[ -f "${MEMBEROF_LDIF}" ]]; then
    ldapmodify -Y EXTERNAL -H "ldapi:///" -f "${MEMBEROF_LDIF}" 2>&1 || true
fi

cleanup
SLAPD_PID=""
