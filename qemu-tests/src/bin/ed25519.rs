#![no_std]
#![no_main]

extern crate panic_semihosting;
use core::convert::TryFrom;

use cortex25519::ed25519::*;
use cortex_m_rt::entry;
use cortex_m_semihosting::{debug, hprint, hprintln};
use wycheproof::wycheproof::*;
use wycheproof_gen::generate_data;

const THE_TESTS: WycheproofTest =
    generate_data!("tests/eddsa_test.json", "eddsa_verify_schema.json");

#[entry]
fn main() -> ! {
    hprint!("running tests...\n").ok();

    for testgroup in THE_TESTS.test_groups {
        if let TestGroup::EddsaVerify { key, tests } = testgroup {
            run_eddsa_sec2pub(&key);

            for testcase in tests.as_ref() {
                run_eddsa_verify(&key, &testcase);
            }
        }
    }

    for testgroup in THE_TESTS.test_groups {
        if let TestGroup::EddsaVerify { key, tests } = testgroup {
            for testcase in tests.as_ref() {
                match testcase.result {
                    ExpectedResult::Valid => run_eddsa_sign(&key, &testcase),
                    _ => {}
                }
            }
        }
    }

    hprintln!("done.").ok();

    debug::exit(debug::EXIT_SUCCESS);
    loop {
        continue;
    }
}

fn fail() {
    debug::exit(debug::EXIT_FAILURE);
    loop {
        continue;
    }
}

fn run_eddsa_verify(test_key: &Key, test_data: &SignatureTestVector) {
    hprint!("EddsaVerify test case {:4}: ", test_data.tc_id).ok();

    let valid = if test_data.sig.len() == 64 {
        let pk = <[u8; 32]>::try_from(test_key.pk).unwrap();
        let sig = <[u8; 64]>::try_from(test_data.sig).unwrap();
        verify(test_data.msg, pk, sig).is_ok()
    } else {
        false
    };

    match test_data.result {
        ExpectedResult::Valid => {
            if !valid {
                hprintln!("FAIL (expected VALID, but isn't)").ok();
                fail();
            } else {
                hprintln!("OK (valid input)").ok();
            }
        }
        ExpectedResult::Invalid => {
            if valid {
                hprintln!("FAIL (expected INVALID, but isn't)").ok();
                fail();
            } else {
                hprintln!("OK (invalid input)").ok();
            }
        }
        ExpectedResult::Acceptable => {
            hprintln!("ACCEPTABLE in any case").ok();
        }
    }
}

fn run_eddsa_sign(test_key: &Key, test_data: &SignatureTestVector) {
    hprint!("EddsaVerify test sign {:4}: ", test_data.tc_id).ok();

    let sk = <[u8; 32]>::try_from(test_key.sk).unwrap();
    let sig = <[u8; 64]>::try_from(test_data.sig).unwrap();

    let testsig = sign(&test_data.msg, sk);
    let valid = testsig == sig;

    if valid {
        hprintln!("OK").ok();
    } else {
        hprintln!("FAIL signatures do not match").ok();
        fail();
    }
}

fn run_eddsa_sec2pub(test_key: &Key) {
    hprint!("Eddsa test sec2pub: ").ok();

    let sk = <[u8; 32]>::try_from(test_key.sk).unwrap();
    let pk = <[u8; 32]>::try_from(test_key.pk).unwrap();

    let got_pk = secret_to_public(sk);
    let valid = pk == got_pk;

    if valid {
        hprintln!("OK").ok();
    } else {
        hprintln!("FAIL pubkeys do not match").ok();
        fail();
    }
}
