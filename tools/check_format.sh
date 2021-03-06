#!/bin/bash

# Fast fail the script on failures.
set -e

DARTFMT_OUT=$(dartfmt -n "sec_analyzer")
if [[ ! -z "$DARTFMT_OUT" ]]; then
  printf "sec_analyzer has unformatted Dart files: \n$DARTFMT_OUT\n"
  printf "Run 'dartfmt -w sec_analyzer'"
  exit 1
fi

DARTFMT_OUT=$(dartfmt -n "secdart")
if [[ ! -z "$DARTFMT_OUT" ]]; then
  printf "secdart has unformatted Dart files: \n$DARTFMT_OUT\n"
  printf "Run 'dartfmt -w secdart'"
  exit 1
fi

DARTFMT_OUT=$(dartfmt -n "web_api")
if [[ ! -z "$DARTFMT_OUT" ]]; then
  printf "web_api has unformatted Dart files: \n$DARTFMT_OUT\n"
  printf "Run 'dartfmt -w web_api'"
  exit 1
fi

DARTFMT_OUT=$(dartfmt -n "security_transformer")
if [[ ! -z "$DARTFMT_OUT" ]]; then
  printf "security_transformer has unformatted Dart files: \n$DARTFMT_OUT\n"
  printf "Run 'dartfmt -w security_transformer'"
  exit 1
fi