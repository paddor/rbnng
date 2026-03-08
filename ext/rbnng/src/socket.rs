use std::{ffi::{c_char, CString}, os::raw::c_void, sync::OnceLock};

use magnus::{
    error::Result, method, prelude::*, scan_args::{get_kwargs, scan_args}, typed_data::Obj, Error,
    Module, RModule, RString, Ruby, Value,
};

use crate::{error::nng_error, ffi, msg::Message};

// ---------------------------------------------------------------------------
// Socket wrapper
// ---------------------------------------------------------------------------

// Newtype to allow passing *mut NngMsg across the GVL-release boundary.
struct SendMsgPtr(*mut ffi::NngMsg);
unsafe impl Send for SendMsgPtr {}

#[magnus::wrap(class = "NNG::Socket::Base", free_immediately, size)]
#[derive(Default)]
pub struct Socket {
    pub(crate) inner: OnceLock<ffi::NngSocket>,
}

unsafe impl Send for Socket {}
unsafe impl Sync for Socket {}

impl Socket {
    fn new() -> Self {
        Socket {
            inner: OnceLock::new(),
        }
    }

    pub(crate) fn nng_socket(&self, ruby: &Ruby) -> Result<ffi::NngSocket> {
        self.inner
            .get()
            .copied()
            .ok_or_else(|| Error::new(ruby.exception_runtime_error(), "socket not initialized"))
    }
}

impl Drop for Socket {
    fn drop(&mut self) {
        if let Some(&socket) = self.inner.get() {
            unsafe { ffi::nng_close(socket) };
        }
    }
}

// ---------------------------------------------------------------------------
// GVL release helper
// ---------------------------------------------------------------------------

fn call_without_gvl<F, R>(f: F) -> R
where
    F: FnOnce() -> R + Send,
    R: Send,
{
    struct Data<F, R> {
        func: Option<F>,
        result: Option<R>,
    }

    unsafe extern "C" fn trampoline<F, R>(ptr: *mut c_void) -> *mut c_void
    where
        F: FnOnce() -> R,
    {
        let data = &mut *(ptr as *mut Data<F, R>);
        data.result = Some((data.func.take().unwrap())());
        std::ptr::null_mut()
    }

    let mut data = Data::<F, R> {
        func: Some(f),
        result: None,
    };

    unsafe {
        rb_sys::rb_thread_call_without_gvl(
            Some(trampoline::<F, R>),
            &mut data as *mut _ as *mut c_void,
            None,
            std::ptr::null_mut(),
        );
    }

    data.result.unwrap()
}

// ---------------------------------------------------------------------------
// Shared socket methods (defined on Base, inherited by all subclasses)
// ---------------------------------------------------------------------------

fn socket_close(rb_self: Obj<Socket>) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let rv = unsafe { ffi::nng_close(socket) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_listen(rb_self: Obj<Socket>, url: RString) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let url = CString::new(unsafe { url.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "URL contains null byte"))?;
    let rv = unsafe { ffi::nng_listen(socket, url.as_ptr(), std::ptr::null_mut(), 0) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_dial(rb_self: Obj<Socket>, url: RString) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let url = CString::new(unsafe { url.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "URL contains null byte"))?;
    let rv = unsafe { ffi::nng_dial(socket, url.as_ptr(), std::ptr::null_mut(), 0) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_receive(rb_self: Obj<Socket>) -> Result<Message> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;

    let (rv, SendMsgPtr(msg_ptr)) = call_without_gvl(move || {
        let mut msg: *mut ffi::NngMsg = std::ptr::null_mut();
        let rv = unsafe { ffi::nng_recvmsg(socket, &mut msg, 0) };
        (rv, SendMsgPtr(msg))
    });

    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(Message::new(msg_ptr))
}

fn socket_send(rb_self: Obj<Socket>, data: RString) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let bytes: Vec<u8> = unsafe { data.as_slice() }.to_vec();

    let rv = call_without_gvl(move || {
        let mut msg: *mut ffi::NngMsg = std::ptr::null_mut();
        let rv = unsafe { ffi::nng_msg_alloc(&mut msg, 0) };
        if rv != 0 {
            return rv;
        }
        let rv =
            unsafe { ffi::nng_msg_append(msg, bytes.as_ptr() as *const c_void, bytes.len()) };
        if rv != 0 {
            unsafe { ffi::nng_msg_free(msg) };
            return rv;
        }
        // nng_sendmsg takes ownership of msg on success
        let rv = unsafe { ffi::nng_sendmsg(socket, msg, 0) };
        if rv != 0 {
            unsafe { ffi::nng_msg_free(msg) };
        }
        rv
    });

    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_forward(rb_self: Obj<Socket>, msg: Obj<Message>) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let msg_ptr = msg.take();
    if msg_ptr.is_null() {
        return Err(Error::new(
            ruby.exception_runtime_error(),
            "message already consumed",
        ));
    }

    let wrapped = SendMsgPtr(msg_ptr);
    let (rv, SendMsgPtr(returned_ptr)) = call_without_gvl(move || {
        let rv = unsafe { ffi::nng_sendmsg(socket, wrapped.0, 0) };
        (rv, wrapped)
    });

    if rv != 0 {
        unsafe { ffi::nng_msg_free(returned_ptr) };
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_get_opt_int(rb_self: Obj<Socket>, name: RString) -> Result<i32> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let mut val: std::ffi::c_int = 0;
    let rv = unsafe { ffi::nng_socket_get_int(socket, name.as_ptr(), &mut val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(val)
}

fn socket_set_opt_int(rb_self: Obj<Socket>, name: RString, val: i32) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let rv = unsafe { ffi::nng_socket_set_int(socket, name.as_ptr(), val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_get_opt_ms(rb_self: Obj<Socket>, name: RString) -> Result<i32> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let mut val: i32 = 0;
    let rv = unsafe { ffi::nng_socket_get_ms(socket, name.as_ptr(), &mut val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(val)
}

fn socket_set_opt_ms(rb_self: Obj<Socket>, name: RString, val: i32) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let rv = unsafe { ffi::nng_socket_set_ms(socket, name.as_ptr(), val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_get_opt_size(rb_self: Obj<Socket>, name: RString) -> Result<usize> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let mut val: usize = 0;
    let rv = unsafe { ffi::nng_socket_get_size(socket, name.as_ptr(), &mut val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(val)
}

fn socket_set_opt_size(rb_self: Obj<Socket>, name: RString, val: usize) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let rv = unsafe { ffi::nng_socket_set_size(socket, name.as_ptr(), val) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_get_opt_string(rb_self: Obj<Socket>, name: RString) -> Result<String> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let mut ptr: *mut c_char = std::ptr::null_mut();
    let rv = unsafe { ffi::nng_socket_get_string(socket, name.as_ptr(), &mut ptr) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    let s = unsafe { std::ffi::CStr::from_ptr(ptr) }
        .to_str()
        .unwrap_or("")
        .to_string();
    unsafe { ffi::nng_strfree(ptr) };
    Ok(s)
}

fn socket_set_opt_string(rb_self: Obj<Socket>, name: RString, val: RString) -> Result<()> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let name = CString::new(unsafe { name.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "option name contains null byte"))?;
    let val = CString::new(unsafe { val.as_str() }?)
        .map_err(|_| Error::new(ruby.exception_arg_error(), "value contains null byte"))?;
    let rv = unsafe { ffi::nng_socket_set_string(socket, name.as_ptr(), val.as_ptr()) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(())
}

fn socket_recv_fd(rb_self: Obj<Socket>) -> Result<i32> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let opt = ffi::NNG_OPT_RECVFD.as_ptr() as *const std::ffi::c_char;
    let mut fd: std::ffi::c_int = 0;
    let rv = unsafe { ffi::nng_socket_get_int(socket, opt, &mut fd) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(fd)
}

fn socket_send_fd(rb_self: Obj<Socket>) -> Result<i32> {
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let opt = ffi::NNG_OPT_SENDFD.as_ptr() as *const std::ffi::c_char;
    let mut fd: std::ffi::c_int = 0;
    let rv = unsafe { ffi::nng_socket_get_int(socket, opt, &mut fd) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(fd)
}

// ---------------------------------------------------------------------------
// Per-protocol initialize helpers
// ---------------------------------------------------------------------------

macro_rules! define_initialize {
    ($fn_name:ident, $open:path, $open_raw:path) => {
        fn $fn_name(rb_self: Obj<Socket>, args: &[Value]) -> Result<Obj<Socket>> {
            let ruby = Ruby::get_with(rb_self);
            let args = scan_args::<(), (), (), (), _, ()>(args)?;
            let kw = get_kwargs::<_, (), (Option<bool>,), ()>(args.keywords, &[], &["raw"])?;
            let raw = kw.optional.0.unwrap_or(false);
            let mut socket = ffi::NngSocket { id: 0 };
            let rv = if raw {
                unsafe { $open_raw(&mut socket) }
            } else {
                unsafe { $open(&mut socket) }
            };
            if rv != 0 {
                return Err(nng_error(&ruby, rv));
            }
            rb_self.ivar_set("@raw", raw)?;
            rb_self.inner.set(socket).map_err(|_| {
                Error::new(ruby.exception_runtime_error(), "socket already initialized")
            })?;
            Ok(rb_self)
        }
    };
}

define_initialize!(pair0_init, ffi::nng_pair0_open, ffi::nng_pair0_open_raw);
define_initialize!(pair1_init, ffi::nng_pair1_open, ffi::nng_pair1_open_raw);
define_initialize!(bus0_init_inner, ffi::nng_bus0_open, ffi::nng_bus0_open_raw);
define_initialize!(pub0_init, ffi::nng_pub0_open, ffi::nng_pub0_open_raw);
define_initialize!(sub0_init_inner, ffi::nng_sub0_open, ffi::nng_sub0_open_raw);
define_initialize!(push0_init, ffi::nng_push0_open, ffi::nng_push0_open_raw);
define_initialize!(pull0_init, ffi::nng_pull0_open, ffi::nng_pull0_open_raw);
define_initialize!(req0_init, ffi::nng_req0_open, ffi::nng_req0_open_raw);
define_initialize!(rep0_init, ffi::nng_rep0_open, ffi::nng_rep0_open_raw);
define_initialize!(
    surveyor0_init,
    ffi::nng_surveyor0_open,
    ffi::nng_surveyor0_open_raw
);
define_initialize!(
    respondent0_init,
    ffi::nng_respondent0_open,
    ffi::nng_respondent0_open_raw
);

fn sub0_init(rb_self: Obj<Socket>, args: &[Value]) -> Result<Obj<Socket>> {
    let rb_self = sub0_init_inner(rb_self, args)?;
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let opt = ffi::NNG_OPT_SUB_SUBSCRIBE.as_ptr() as *const std::ffi::c_char;
    let rv = unsafe { ffi::nng_socket_set(socket, opt, std::ptr::null(), 0) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(rb_self)
}

fn bus0_init(rb_self: Obj<Socket>, args: &[Value]) -> Result<Obj<Socket>> {
    let rb_self = bus0_init_inner(rb_self, args)?;
    let ruby = Ruby::get_with(rb_self);
    let socket = rb_self.nng_socket(&ruby)?;
    let opt = ffi::NNG_OPT_RECVTIMEO.as_ptr() as *const std::ffi::c_char;
    let rv = unsafe { ffi::nng_socket_set_ms(socket, opt, 100) };
    if rv != 0 {
        return Err(nng_error(&ruby, rv));
    }
    Ok(rb_self)
}

// ---------------------------------------------------------------------------
// Ruby class registration
// ---------------------------------------------------------------------------

pub fn init(ruby: &Ruby, nng: RModule) -> Result<()> {
    let socket_module = nng.define_module("Socket")?;

    let base = socket_module.define_class("Base", ruby.class_object())?;
    base.define_alloc_func::<Socket>();
    base.define_method("close", method!(socket_close, 0))?;
    base.define_method("listen", method!(socket_listen, 1))?;
    base.define_method("dial", method!(socket_dial, 1))?;
    base.define_method("receive", method!(socket_receive, 0))?;
    base.define_method("send", method!(socket_send, 1))?;
    base.define_method("forward", method!(socket_forward, 1))?;
    base.define_method("recv_fd", method!(socket_recv_fd, 0))?;
    base.define_method("send_fd", method!(socket_send_fd, 0))?;
    base.define_method("get_opt_int", method!(socket_get_opt_int, 1))?;
    base.define_method("set_opt_int", method!(socket_set_opt_int, 2))?;
    base.define_method("get_opt_ms", method!(socket_get_opt_ms, 1))?;
    base.define_method("set_opt_ms", method!(socket_set_opt_ms, 2))?;
    base.define_method("get_opt_size", method!(socket_get_opt_size, 1))?;
    base.define_method("set_opt_size", method!(socket_set_opt_size, 2))?;
    base.define_method("get_opt_string", method!(socket_get_opt_string, 1))?;
    base.define_method("set_opt_string", method!(socket_set_opt_string, 2))?;

    macro_rules! register {
        ($name:expr, $init:ident) => {{
            let cls = socket_module.define_class($name, base)?;
            cls.define_method("initialize", method!($init, -1))?;
        }};
    }

    register!("Pair0", pair0_init);
    register!("Pair1", pair1_init);
    register!("Bus0", bus0_init);
    register!("Pub0", pub0_init);
    register!("Sub0", sub0_init);
    register!("Push0", push0_init);
    register!("Pull0", pull0_init);
    register!("Req0", req0_init);
    register!("Rep0", rep0_init);
    register!("Surveyor0", surveyor0_init);
    register!("Respondent0", respondent0_init);

    Ok(())
}
