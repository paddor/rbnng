use std::cell::UnsafeCell;
use std::os::raw::c_void;

use magnus::{error::Result, method, prelude::*, typed_data::Obj, Error, Module, RModule, RString, Ruby};

use crate::{error::nng_error, ffi};

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

    fn ensure_valid(&self, ruby: &Ruby) -> Result<*mut ffi::NngMsg> {
        let ptr = self.ptr();
        if ptr.is_null() {
            return Err(Error::new(
                ruby.exception_runtime_error(),
                "message already consumed",
            ));
        }
        Ok(ptr)
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

    fn body(rb_self: Obj<Self>) -> Result<RString> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let body = unsafe {
            let data = ffi::nng_msg_body(ptr) as *const u8;
            let len = ffi::nng_msg_len(ptr);
            std::slice::from_raw_parts(data, len)
        };
        Ok(ruby.str_from_slice(body))
    }

    fn header(rb_self: Obj<Self>) -> Result<RString> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let header = unsafe {
            let data = ffi::nng_msg_header(ptr) as *const u8;
            let len = ffi::nng_msg_header_len(ptr);
            std::slice::from_raw_parts(data, len)
        };
        Ok(ruby.str_from_slice(header))
    }

    fn header_append(rb_self: Obj<Self>, data: RString) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let bytes = unsafe { data.as_slice() };
        let rv = unsafe {
            ffi::nng_msg_header_append(ptr, bytes.as_ptr() as *const c_void, bytes.len())
        };
        if rv != 0 {
            return Err(nng_error(&ruby, rv));
        }
        Ok(())
    }

    fn header_prepend(rb_self: Obj<Self>, data: RString) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let bytes = unsafe { data.as_slice() };
        let rv = unsafe {
            ffi::nng_msg_header_insert(ptr, bytes.as_ptr() as *const c_void, bytes.len())
        };
        if rv != 0 {
            return Err(nng_error(&ruby, rv));
        }
        Ok(())
    }

    fn header_clear(rb_self: Obj<Self>) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        unsafe { ffi::nng_msg_header_clear(ptr) };
        Ok(())
    }

    fn header_trim(rb_self: Obj<Self>, n: usize) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let rv = unsafe { ffi::nng_msg_header_trim(ptr, n) };
        if rv != 0 {
            return Err(nng_error(&ruby, rv));
        }
        Ok(())
    }

    fn body_clear(rb_self: Obj<Self>) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        unsafe { ffi::nng_msg_clear(ptr) };
        Ok(())
    }

    fn body_append(rb_self: Obj<Self>, data: RString) -> Result<()> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let bytes = unsafe { data.as_slice() };
        let rv =
            unsafe { ffi::nng_msg_append(ptr, bytes.as_ptr() as *const c_void, bytes.len()) };
        if rv != 0 {
            return Err(nng_error(&ruby, rv));
        }
        Ok(())
    }

    fn dup(rb_self: Obj<Self>) -> Result<Message> {
        let ruby = Ruby::get_with(rb_self);
        let ptr = rb_self.ensure_valid(&ruby)?;
        let mut new_ptr: *mut ffi::NngMsg = std::ptr::null_mut();
        let rv = unsafe { ffi::nng_msg_dup(&mut new_ptr, ptr) };
        if rv != 0 {
            return Err(nng_error(&ruby, rv));
        }
        Ok(Message::new(new_ptr))
    }

    fn is_consumed(rb_self: Obj<Self>) -> bool {
        rb_self.ptr().is_null()
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
    cls.define_method("body_clear", method!(Message::body_clear, 0))?;
    cls.define_method("body_append", method!(Message::body_append, 1))?;
    cls.define_method("header", method!(Message::header, 0))?;
    cls.define_method("header_append", method!(Message::header_append, 1))?;
    cls.define_method("header_prepend", method!(Message::header_prepend, 1))?;
    cls.define_method("header_clear", method!(Message::header_clear, 0))?;
    cls.define_method("header_trim", method!(Message::header_trim, 1))?;
    cls.define_method("dup", method!(Message::dup, 0))?;
    cls.define_method("consumed?", method!(Message::is_consumed, 0))?;
    Ok(())
}
