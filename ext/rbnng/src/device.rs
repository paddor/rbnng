use std::os::raw::c_void;

use magnus::{error::Result, function, prelude::*, typed_data::Obj, Module, RModule, Ruby};

use crate::{error::nng_error, ffi, socket::Socket};

fn device_start(s1: Obj<Socket>, s2: Obj<Socket>) -> Result<()> {
    let ruby = Ruby::get_with(s1);
    let sock1 = s1.nng_socket(&ruby)?;
    let sock2 = s2.nng_socket(&ruby)?;

    // nng_device blocks forever, so run it without the GVL
    struct SocketPair(ffi::NngSocket, ffi::NngSocket);
    unsafe impl Send for SocketPair {}

    let pair = SocketPair(sock1, sock2);

    unsafe extern "C" fn trampoline(ptr: *mut c_void) -> *mut c_void {
        let pair = &*(ptr as *const SocketPair);
        let rv = ffi::nng_device(pair.0, pair.1);
        rv as isize as *mut c_void
    }

    let rv = unsafe {
        rb_sys::rb_thread_call_without_gvl(
            Some(trampoline),
            &pair as *const _ as *mut c_void,
            None,
            std::ptr::null_mut(),
        ) as i32
    };

    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

pub fn init(ruby: &Ruby, nng: RModule) -> Result<()> {
    let device = nng.define_module("Device")?;
    device.define_singleton_method("start", function!(device_start, 2))?;
    Ok(())
}
