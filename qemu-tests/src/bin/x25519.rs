#![no_std]
#![no_main]

extern crate panic_semihosting;
use core::convert::TryFrom;

use cortex25519::x25519::*;
use cortex_m_rt::entry;
use cortex_m_semihosting::{debug, hprint, hprintln};
use wycheproof::wycheproof::*;
use wycheproof_gen::generate_data;

const THE_TESTS: WycheproofTest = generate_data!("tests/x25519_test.json", "xdh_comp_schema.json");

#[entry]
fn main() -> ! {
    hprint!("running tests...\n").ok();

    for testgroup in THE_TESTS.test_groups {
        if let TestGroup::XdhComp { curve, tests } = testgroup {
            for testcase in tests.as_ref() {
                run_x25519_comparison(&curve, &testcase);
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

/// Returns `true` on (exempted) failure, `false` on pass
fn run_x25519_comparison(_curve: &str, test_data: &XdhTestVector) {
    let tc_id = test_data.tc_id;
    hprint!("X25519 test case {:4}: ", tc_id).ok();

    let private = <[u8; 32]>::try_from(test_data.private);
    let public = <[u8; 32]>::try_from(test_data.public);
    let expect = <[u8; 32]>::try_from(test_data.shared);

    let valid = if private.is_err() || public.is_err() || expect.is_err() {
        false
    } else {
        let shared = scalarmult(private.unwrap(), public.unwrap());
        shared == expect.unwrap()
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
            if valid {
                hprintln!("ACCEPTABLE (valid)").ok();
            } else {
                hprintln!("ACCEPTABLE (invalid)").ok();
            }
        }
    }
}
