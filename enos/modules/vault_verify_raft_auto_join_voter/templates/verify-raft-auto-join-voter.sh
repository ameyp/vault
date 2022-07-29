#!/usr/bin/env bash

set -e

binpath=${vault_install_dir}/vault

fail() {
	echo "$1" 1>&2
	exit 1
}

test -x "$binpath" || fail "unable to locate vault binary at $binpath"

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='${vault_token}'

voter_status=$($binpath operator raft list-peers -format json | jq -Mr --argjson expected "true" '.data.config.servers[] | select(.address=="${vault_cluster_addr}") | .voter == $expected')

if [[ "$voter_status" != 'true' ]]; then
  fail "expected ${vault_cluster_addr} to be Raft voter, got voter status: $voter_status"
fi
