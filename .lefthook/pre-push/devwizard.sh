#!/usr/bin/env bash
exec bash "$(git rev-parse --show-toplevel)/.lefthook/devwizard-checks.sh" pre-push "$@"
