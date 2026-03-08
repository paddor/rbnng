fn main() {
    if pkg_config::probe_library("libnng").is_err() {
        println!("cargo:rustc-link-lib=nng");
        println!("cargo:rustc-link-search=native=/usr/lib/x86_64-linux-gnu");
    }
}
