use core::arch::global_asm;
use core::convert::TryInto;
use core::mem::transmute;
use core::ops::{Add, Index, IndexMut, Mul, Neg, Sub};

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Scalar([u32; 8]);

impl Index<usize> for Scalar {
    type Output = u32;
    fn index(&self, i: usize) -> &u32 {
        &(self.0[i])
    }
}

impl IndexMut<usize> for Scalar {
    fn index_mut(&mut self, i: usize) -> &mut u32 {
        &mut (self.0[i])
    }
}

impl Index<usize> for Scalar512 {
    type Output = u32;
    fn index(&self, i: usize) -> &u32 {
        &(self.0[i])
    }
}

impl IndexMut<usize> for Scalar512 {
    fn index_mut(&mut self, i: usize) -> &mut u32 {
        &mut (self.0[i])
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Scalar512([u32; 16]);

impl Scalar {
    pub fn as_bytes(&self) -> &[u8; 32] {
        unsafe { core::mem::transmute(self) }
    }

    pub fn from_bytes_mod_order(bytes: [u8; 32]) -> Self {
        Scalar(unsafe { transmute(bytes) }).reduce()
    }

    pub fn from_bytes_mod_order_wide(bytes: &[u8; 64]) -> Self {
        let words: [u32; 16] = unsafe { transmute(*bytes) };
        let low = Scalar(words[..8].try_into().unwrap());
        let high = Scalar(words[8..].try_into().unwrap());
        (low.raw_mul(R) + high.raw_mul(RR)).montgomery_reduce()
    }

    fn reduce(&self) -> Scalar {
        self.raw_mul(R).montgomery_reduce()
    }

    pub fn from_canonical_bytes(bytes: [u8; 32]) -> Option<Self> {
        // Check that the high bit is not set
        if (bytes[31] >> 7) != 0u8 {
            return None;
        }
        let candidate = Scalar(unsafe { transmute(bytes) });
        if candidate == candidate.reduce() {
            Some(candidate)
        } else {
            None
        }
    }

    fn raw_mul(self, b: Scalar) -> Scalar512 {
        let a = self;

        let mut res = Scalar512([0; 16]);
        for i in 0..8 {
            let mut carry = 0;
            for j in 0..8 {
                let val;
                (val, carry) = a[i].carrying_mul(b[j], carry);
                let add_carry;
                (res[i + j], add_carry) = res[i + j].carrying_add(val, false);
                carry += add_carry as u32;
            }
            for j in 8..(16 - i) {
                let add_carry;
                (res[i + j], add_carry) = res[i + j].carrying_add(carry, false);
                carry = add_carry as u32;
            }
            assert!(carry == 0);
        }
        res
    }
}

impl Scalar512 {
    fn montgomery_reduce(self) -> Scalar {
        let mut t = self;

        for i in 0..8 {
            let mut carry = 0;
            let m = t[i].wrapping_mul(LFACTOR);
            for j in 0..8 {
                let val;
                (val, carry) = L[j].carrying_mul(m, carry);
                let add_carry;
                (t[i + j], add_carry) = t[i + j].carrying_add(val, false);
                carry += add_carry as u32;
            }
            for j in 8..(16 - i) {
                let add_carry;
                (t[i + j], add_carry) = t[i + j].carrying_add(carry, false);
                carry = add_carry as u32;
            }
            assert!(carry == 0);
        }
        Scalar(t.0[8..].try_into().unwrap()) - L
    }
}

impl Add<Scalar> for Scalar {
    type Output = Scalar;
    fn add(self, b: Scalar) -> Self::Output {
        let mut a = self;
        let mut carry = false;
        for i in 0..8 {
            (a[i], carry) = a[i].carrying_add(b[i], carry);
        }
        a - L
    }
}

impl Add<Scalar512> for Scalar512 {
    type Output = Scalar512;
    fn add(self, b: Scalar512) -> Self::Output {
        let mut a = self;
        let mut carry = false;
        for i in 0..16 {
            (a[i], carry) = a[i].carrying_add(b[i], carry);
        }
        assert!(!carry);
        a
    }
}

impl Sub<Scalar> for Scalar {
    type Output = Scalar;
    fn sub(self, b: Scalar) -> Self::Output {
        let mut a = self;
        let mut borrow = false;
        for i in 0..8 {
            (a[i], borrow) = a[i].borrowing_sub(b[i], borrow);
        }

        // conditionally add l if the difference is negative
        let underflow_mask = ((!borrow) as u32).wrapping_sub(1);
        let mut carry = false;
        for i in 0..8 {
            (a[i], carry) = a[i].carrying_add(L[i] & underflow_mask, carry);
        }

        a
    }
}

impl Mul<Scalar> for Scalar {
    type Output = Scalar;
    fn mul(self, rhs: Scalar) -> Self::Output {
        self.raw_mul(rhs)
            .montgomery_reduce()
            .raw_mul(RR)
            .montgomery_reduce()
    }
}

/// `L` is the order of base point, i.e. 2^252 + 27742317777372353535851937790883648493
const L: Scalar = Scalar([
    0x5cf5d3ed, 0x5812631a, 0xa2f79cd6, 0x14def9de, 0x00000000, 0x00000000, 0x00000000, 0x10000000,
]);

/// `R` = R % L where R = 2^256
const R: Scalar = Scalar([
    0x8d98951d, 0xd6ec3174, 0x737dcf70, 0xc6ef5bf4, 0xfffffffe, 0xffffffff, 0xffffffff, 0x0fffffff,
]);

/// `RR` = (R^2) % L where R = 2^256
const RR: Scalar = Scalar([
    0x449c0f01, 0xa40611e3, 0x68859347, 0xd00e1ba7, 0x17f5be65, 0xceec73d2, 0x7c309a3d, 0x0399411b,
]);

/// `L` * `LFACTOR` = -1 (mod 2^32)
const LFACTOR: u32 = 0x12547e1b;
