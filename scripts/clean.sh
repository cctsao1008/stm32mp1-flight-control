#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output/odyssey"

if [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo "Nothing to clean: ${OUTPUT_DIR} does not exist."
    exit 0
fi

echo "Removing generated Buildroot output: ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"
