use std::env;

fn main() {
    let _target = env::var("TARGET").unwrap();

    #[cfg(not(feature = "force-dalek-backend"))]
    if _target.starts_with("thumbv") {
        println!("cargo:rustc-cfg=cortex_m");

        let mut cc = cc::Build::new();
        cc.file("src/cortex_m_fe25519.s");
        cc.file("src/cortex_m_curve25519.s");
        cc.file("src/cortex_m_ed25519.s");
        if _target.starts_with("thumbv8m.main") {
            cc.flag("-march=armv8-m.main+dsp");
        }
        cc.compile("cortex25519");
    }
}
