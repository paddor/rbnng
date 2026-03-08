mod error;
mod ffi;
mod msg;
mod socket;

use magnus::{function, prelude::*, Error, RArray, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let nng = ruby.define_module("NNG")?;
    nng.define_singleton_method("nng_version", function!(nng_version, 0))?;
    error::init(ruby, nng)?;
    msg::init(ruby, nng)?;
    socket::init(ruby, nng)?;
    Ok(())
}

fn nng_version() -> RArray {
    let ruby = unsafe { Ruby::get_unchecked() };
    let version_str = unsafe {
        std::ffi::CStr::from_ptr(ffi::nng_version())
            .to_str()
            .unwrap_or("0.0.0")
    };
    let parts: Vec<u32> = version_str
        .splitn(3, '.')
        .map(|s| s.parse().unwrap_or(0))
        .collect();
    let arr = ruby.ary_new_capa(3);
    arr.push(*parts.get(0).unwrap_or(&0)).unwrap();
    arr.push(*parts.get(1).unwrap_or(&0)).unwrap();
    arr.push(*parts.get(2).unwrap_or(&0)).unwrap();
    arr
}
