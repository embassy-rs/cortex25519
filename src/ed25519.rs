pub use custom_hash::VerifyError;
use sha2::Sha512;

pub fn verify(message: &[u8], public_key: [u8; 32], sig: [u8; 64]) -> Result<(), VerifyError> {
    custom_hash::verify::<Sha512>(message, public_key, sig)
}

pub fn sign(message: &[u8], secret_key: [u8; 32]) -> [u8; 64] {
    custom_hash::sign::<Sha512>(message, secret_key)
}

pub fn secret_to_public(secret_key: [u8; 32]) -> [u8; 32] {
    custom_hash::secret_to_public::<Sha512>(secret_key)
}

pub mod custom_hash {
    use core::convert::TryInto;

    use generic_array::typenum::consts;
    use generic_array::{ArrayLength, GenericArray};
    use sha2::Digest;

    use crate::backend::*;

    pub trait Ed25519DigestLength: ArrayLength<u8> {
        fn hash_to_scalar(hash: GenericArray<u8, Self>) -> Scalar;
        fn hash_32x2<D: Digest<OutputSize = Self>>(seed: [u8; 32]) -> ([u8; 32], [u8; 32]);
    }

    impl Ed25519DigestLength for consts::U32 {
        fn hash_to_scalar(hash: GenericArray<u8, Self>) -> Scalar {
            Scalar::from_bytes_mod_order(hash.into())
        }

        fn hash_32x2<D: Digest<OutputSize = Self>>(seed: [u8; 32]) -> ([u8; 32], [u8; 32]) {
            let mut h = D::new();
            h.update(&[0x01]);
            h.update(seed);
            let a = h.finalize().into();

            let mut h = D::new();
            h.update(&[0x02]);
            h.update(seed);
            let b = h.finalize().into();

            (a, b)
        }
    }

    impl Ed25519DigestLength for consts::U64 {
        fn hash_to_scalar(hash: GenericArray<u8, Self>) -> Scalar {
            Scalar::from_bytes_mod_order_wide(&hash.into())
        }

        fn hash_32x2<D: Digest<OutputSize = Self>>(seed: [u8; 32]) -> ([u8; 32], [u8; 32]) {
            let mut h = D::new();
            h.update(seed);
            let res: [u8; 64] = h.finalize().into();

            let a = res[..32].try_into().unwrap();
            let b = res[32..].try_into().unwrap();
            (a, b)
        }
    }

    #[derive(PartialEq, Eq, Clone, Copy, Debug)]
    pub struct VerifyError;

    pub fn verify<D>(message: &[u8], public_key: [u8; 32], sig: [u8; 64]) -> Result<(), VerifyError>
    where
        D: Digest,
        D::OutputSize: Ed25519DigestLength,
    {
        let sig_r: [u8; 32] = sig[..32].try_into().unwrap();
        let sig_s: [u8; 32] = sig[32..].try_into().unwrap();

        // Check S is canonical (smaller than the group order)
        let sig_s: Option<Scalar> = Scalar::from_canonical_bytes(sig_s).into();
        let sig_s = sig_s.ok_or(VerifyError)?;

        let mut h = D::new();
        h.update(sig_r);
        h.update(public_key);
        h.update(message);
        let k = D::OutputSize::hash_to_scalar(h.finalize());

        let pubkey_neg = -CompressedEdwardsY(public_key)
            .decompress()
            .ok_or(VerifyError)?;

        let res = k * pubkey_neg + sig_s * ED25519_BASEPOINT_POINT;
        let res_compressed = res.compress().0;

        if res_compressed != sig_r {
            return Err(VerifyError);
        }

        Ok(())
    }

    pub fn sign<D>(message: &[u8], secret_key: [u8; 32]) -> [u8; 64]
    where
        D: Digest,
        D::OutputSize: Ed25519DigestLength,
    {
        let i = key_info::<D>(secret_key);

        // First hash
        let mut h = D::new();
        h.update(i.secret_nonce);
        h.update(message);
        let r = D::OutputSize::hash_to_scalar(h.finalize());

        let r_point = r * ED25519_BASEPOINT_POINT;
        let rr = r_point.compress().0;

        // Second hash
        let mut h = D::new();
        h.update(rr);
        h.update(i.public_key);
        h.update(message);
        let k = D::OutputSize::hash_to_scalar(h.finalize());

        // Magic calculation
        let s = r + k * i.secret_scalar;

        let mut signature = [0; 64];
        signature[..32].copy_from_slice(&rr);
        signature[32..].copy_from_slice(s.as_bytes());
        signature
    }

    struct KeyInfo {
        secret_scalar: Scalar,
        secret_nonce: [u8; 32],
        public_key: [u8; 32],
    }

    fn key_info<D>(secret_key: [u8; 32]) -> KeyInfo
    where
        D: Digest,
        D::OutputSize: Ed25519DigestLength,
    {
        // Derive scalar+nonce from secret key seed
        let (mut secret_scalar, secret_nonce) = D::OutputSize::hash_32x2::<D>(secret_key);
        secret_scalar[0] &= 248;
        secret_scalar[31] &= 127;
        secret_scalar[31] |= 64;
        let secret_scalar = Scalar::from_bytes_mod_order(secret_scalar);

        // Derive public key
        let public_key_point = secret_scalar * ED25519_BASEPOINT_POINT;
        let public_key = public_key_point.compress().0;

        KeyInfo {
            public_key,
            secret_nonce,
            secret_scalar,
        }
    }

    pub fn secret_to_public<D>(secret_key: [u8; 32]) -> [u8; 32]
    where
        D: Digest,
        D::OutputSize: Ed25519DigestLength,
    {
        key_info::<D>(secret_key).public_key
    }
}
