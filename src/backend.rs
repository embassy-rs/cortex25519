use core::arch::global_asm;
use core::ops::{Add, Mul, Neg};

pub use curve25519_dalek::scalar::Scalar;

global_asm!(include_str!("cortex_m_fe25519.s"), options(raw));
global_asm!(include_str!("cortex_m_curve25519.s"), options(raw));
global_asm!(include_str!("cortex_m_ed25519.s"), options(raw));

extern "C" {
    fn curve25519_scalarmult(
        result: *mut [u8; 32],
        scalar: *const [u8; 32],
        point: *const [u8; 32],
    );

    fn ed25519_scalarmult(result: *mut [u32; 32], scalar: *const [u8; 32], point: *const [u32; 32]);
    fn ed25519_decompress(result: *mut [u32; 32], point: *const [u8; 32]) -> bool;
    fn ed25519_compress(result: *mut [u8; 32], point: *const [u32; 32]);
    fn ed25519_neg(point: *mut [u32; 32]);
    fn ed25519_add(result: *mut [u32; 32], a: *const [u32; 32], b: *const [u32; 32]);
}

pub fn x25519(scalar: [u8; 32], point: [u8; 32]) -> [u8; 32] {
    let mut result = [0; 32];
    unsafe { curve25519_scalarmult(&mut result, &scalar, &point) };
    result
}

#[derive(Copy, Clone)]
pub struct CompressedEdwardsY(pub [u8; 32]);

#[derive(Copy, Clone)]
pub struct EdwardsPoint([u32; 32]);

impl CompressedEdwardsY {
    pub fn decompress(&self) -> Option<EdwardsPoint> {
        let mut result = [0; 32];
        match unsafe { ed25519_decompress(&mut result, &self.0) } {
            false => None,
            true => Some(EdwardsPoint(result)),
        }
    }
}

impl EdwardsPoint {
    pub fn compress(&self) -> CompressedEdwardsY {
        let mut result = [0; 32];
        unsafe { ed25519_compress(&mut result, &self.0) };
        CompressedEdwardsY(result)
    }
}

impl Add<EdwardsPoint> for EdwardsPoint {
    type Output = EdwardsPoint;

    fn add(self, rhs: EdwardsPoint) -> Self::Output {
        let mut result = [0; 32];
        unsafe { ed25519_add(&mut result, &self.0, &rhs.0) }
        EdwardsPoint(result)
    }
}

impl Mul<EdwardsPoint> for Scalar {
    type Output = EdwardsPoint;
    fn mul(self, rhs: EdwardsPoint) -> Self::Output {
        let mut result = [0; 32];
        unsafe { ed25519_scalarmult(&mut result, self.as_bytes(), &rhs.0) }
        EdwardsPoint(result)
    }
}

impl Neg for EdwardsPoint {
    type Output = EdwardsPoint;
    fn neg(self) -> Self::Output {
        let mut result = self.0;
        unsafe { ed25519_neg(&mut result) }
        EdwardsPoint(result)
    }
}

#[rustfmt::skip]
pub const ED25519_BASEPOINT_POINT: EdwardsPoint = EdwardsPoint([
    // x
    0x8f25d51a, 0xc9562d60, 0x9525a7b2, 0x692cc760,
    0xfdd6dc5c, 0xc0a4e231, 0xcd6e53fe, 0x216936d3,

    // y
    0x6666_6658, 0x6666_6666, 0x6666_6666, 0x6666_6666,
    0x6666_6666, 0x6666_6666, 0x6666_6666, 0x6666_6666,

    // z
    0x0000_0001, 0x0000_0000, 0x0000_0000, 0x0000_0000,
    0x0000_0000, 0x0000_0000, 0x0000_0000, 0x0000_0000,

    // t = x*y
    0xa5b7dda3, 0x6dde8ab3, 0x775152f5, 0x20f09f80,
    0x64abe37d, 0x66ea4e8e, 0xd78b7665, 0x67875f0f,
]);
