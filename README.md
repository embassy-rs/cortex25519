# cortex25519

Implementations of X25519 key agreement and Ed25519 signature
verification, optimized with ASM for Cortex-M4 processors or higher (ARMv7e-M or higher).

Not reviewed, could have bugs, use at your own risk, etc etc.

## Credits

Original [X25519](https://github.com/Emill/X25519-Cortex-M4) ASM implementation by Emil Lenngren.

Extended to support Ed25519 verify by Dario Nieuwenhuis.

Test harness for running Wycheproof test vectors in QEMU is taken from the [salty](https://github.com/ycrypto/salty) project.

## License

- Main `cortex25519` crate is available under the BSD 2-clause license.
- [Wycheproof](https://github.com/google/wycheproof) test vectors are available under Apache license.
- QEMU test harness is available under Apache + MIT.
