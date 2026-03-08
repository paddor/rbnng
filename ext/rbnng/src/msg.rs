use magnus::{error::Result, method, prelude::*, typed_data::Obj, Module, RModule, Ruby};

use crate::ffi;

#[magnus::wrap(class = "NNG::Message", free_immediately, size)]
pub struct Message(pub *mut ffi::NngMsg);

unsafe impl Send for Message {}
unsafe impl Sync for Message {}

impl Drop for Message {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { ffi::nng_msg_free(self.0) };
        }
    }
}

impl Message {
    fn body(rb_self: Obj<Self>) -> Result<magnus::RString> {
        let ruby = Ruby::get_with(rb_self);
        let body = unsafe {
            let ptr = ffi::nng_msg_body(rb_self.0) as *const u8;
            let len = ffi::nng_msg_len(rb_self.0);
            std::slice::from_raw_parts(ptr, len)
        };
        Ok(ruby.str_from_slice(body))
    }

    fn header(rb_self: Obj<Self>) -> Result<magnus::RString> {
        let ruby = Ruby::get_with(rb_self);
        let header = unsafe {
            let ptr = ffi::nng_msg_header(rb_self.0) as *const u8;
            let len = ffi::nng_msg_header_len(rb_self.0);
            std::slice::from_raw_parts(ptr, len)
        };
        Ok(ruby.str_from_slice(header))
    }
}

pub fn init(ruby: &Ruby, nng: RModule) -> Result<()> {
    let cls = nng.define_class("Message", ruby.class_object())?;
    cls.define_method("body", method!(Message::body, 0))?;
    cls.define_method("header", method!(Message::header, 0))?;
    Ok(())
}
