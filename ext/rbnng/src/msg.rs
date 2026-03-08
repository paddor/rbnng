use std::cell::UnsafeCell;

use magnus::{error::Result, method, prelude::*, typed_data::Obj, Module, RModule, Ruby};

use crate::ffi;

#[magnus::wrap(class = "NNG::Message", free_immediately, size)]
pub struct Message(pub UnsafeCell<*mut ffi::NngMsg>);

unsafe impl Send for Message {}
unsafe impl Sync for Message {}

impl Message {
    pub fn new(ptr: *mut ffi::NngMsg) -> Self {
        Message(UnsafeCell::new(ptr))
    }

    fn ptr(&self) -> *mut ffi::NngMsg {
        unsafe { *self.0.get() }
    }

    /// Takes ownership of the inner pointer, setting it to null.
    /// The caller is responsible for the message lifetime.
    pub fn take(&self) -> *mut ffi::NngMsg {
        unsafe {
            let ptr = *self.0.get();
            *self.0.get() = std::ptr::null_mut();
            ptr
        }
    }

    fn body(rb_self: Obj<Self>) -> Result<magnus::RString> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ptr();
        let body = unsafe {
            let data = ffi::nng_msg_body(ptr) as *const u8;
            let len = ffi::nng_msg_len(ptr);
            std::slice::from_raw_parts(data, len)
        };
        Ok(ruby.str_from_slice(body))
    }

    fn header(rb_self: Obj<Self>) -> Result<magnus::RString> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ptr();
        let header = unsafe {
            let data = ffi::nng_msg_header(ptr) as *const u8;
            let len = ffi::nng_msg_header_len(ptr);
            std::slice::from_raw_parts(data, len)
        };
        Ok(ruby.str_from_slice(header))
    }
}

impl Drop for Message {
    fn drop(&mut self) {
        let ptr = unsafe { *self.0.get() };
        if !ptr.is_null() {
            unsafe { ffi::nng_msg_free(ptr) };
        }
    }
}

pub fn init(ruby: &Ruby, nng: RModule) -> Result<()> {
    let cls = nng.define_class("Message", ruby.class_object())?;
    cls.define_method("body", method!(Message::body, 0))?;
    cls.define_method("header", method!(Message::header, 0))?;
    Ok(())
}
