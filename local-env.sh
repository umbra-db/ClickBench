#!/bin/bash
# Sourced by run-local.sh to resolve the run identity from the environment.
#
# An optional TAG=<label> distinguishes runs that share a machine
# but differ in some build/config knob (e.g. TAG=prefetch). It's appended
# to the result filename/title.
#
# Exports: MACHINE, TAG.
MACHINE=${MACHINE:-$(hostname)}
TAG=${TAG:-}
