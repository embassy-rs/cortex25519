#!/bin/bash

set -euxo pipefail

time cargo run --bin ed25519 --release
time cargo run --bin x25519 --release