use std::ffi::{c_char, c_int, c_void};

pub const NNG_DURATION_INFINITE: i32 = -1;

pub const NNG_EINTR: i32 = 1;
pub const NNG_ENOMEM: i32 = 2;
pub const NNG_EINVAL: i32 = 3;
pub const NNG_EBUSY: i32 = 4;
pub const NNG_ETIMEDOUT: i32 = 5;
pub const NNG_ECONNREFUSED: i32 = 6;
pub const NNG_ECLOSED: i32 = 7;
pub const NNG_EAGAIN: i32 = 8;
pub const NNG_ENOTSUP: i32 = 9;
pub const NNG_EADDRINUSE: i32 = 10;
pub const NNG_ESTATE: i32 = 11;
pub const NNG_ENOENT: i32 = 12;
pub const NNG_EPROTO: i32 = 13;
pub const NNG_EUNREACHABLE: i32 = 14;
pub const NNG_EADDRINVAL: i32 = 15;
pub const NNG_EPERM: i32 = 16;
pub const NNG_EMSGSIZE: i32 = 17;
pub const NNG_ECONNABORTED: i32 = 18;
pub const NNG_ECONNRESET: i32 = 19;
pub const NNG_ECANCELED: i32 = 20;
pub const NNG_ENOFILES: i32 = 21;
pub const NNG_ENOSPC: i32 = 22;
pub const NNG_EEXIST: i32 = 23;
pub const NNG_EREADONLY: i32 = 24;
pub const NNG_EWRITEONLY: i32 = 25;
pub const NNG_ECRYPTO: i32 = 26;
pub const NNG_EPEERAUTH: i32 = 27;
pub const NNG_ENOARG: i32 = 28;
pub const NNG_EAMBIGUOUS: i32 = 29;
pub const NNG_EBADTYPE: i32 = 30;
pub const NNG_ECONNSHUT: i32 = 31;
pub const NNG_EINTERNAL: i32 = 1000;

pub const NNG_OPT_RECVFD: &[u8] = b"recv-fd\0";
pub const NNG_OPT_SENDFD: &[u8] = b"send-fd\0";
pub const NNG_OPT_RECVTIMEO: &[u8] = b"recv-timeout\0";
pub const NNG_OPT_SUB_SUBSCRIBE: &[u8] = b"sub:subscribe\0";

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct NngSocket {
    pub id: u32,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct NngCtx {
    pub id: u32,
}

// nng_msg and nng_aio are opaque structs — use as raw pointers only.
pub enum NngMsg {}
pub enum NngAio {}

unsafe impl Send for NngSocket {}
unsafe impl Sync for NngSocket {}

#[link(name = "nng")]
extern "C" {
    pub fn nng_version() -> *const c_char;
    pub fn nng_close(socket: NngSocket) -> c_int;
    pub fn nng_strerror(err: c_int) -> *const c_char;

    // Protocol open functions
    pub fn nng_pair0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_pair0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_pair1_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_pair1_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_bus0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_bus0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_pub0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_pub0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_sub0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_sub0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_push0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_push0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_pull0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_pull0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_req0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_req0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_rep0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_rep0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_surveyor0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_surveyor0_open_raw(socket: *mut NngSocket) -> c_int;
    pub fn nng_respondent0_open(socket: *mut NngSocket) -> c_int;
    pub fn nng_respondent0_open_raw(socket: *mut NngSocket) -> c_int;

    // Transport
    pub fn nng_listen(
        socket: NngSocket,
        url: *const c_char,
        listener: *mut c_void,
        flags: c_int,
    ) -> c_int;
    pub fn nng_dial(
        socket: NngSocket,
        url: *const c_char,
        dialer: *mut c_void,
        flags: c_int,
    ) -> c_int;

    // Messaging
    pub fn nng_recvmsg(socket: NngSocket, msg: *mut *mut NngMsg, flags: c_int) -> c_int;
    pub fn nng_sendmsg(socket: NngSocket, msg: *mut NngMsg, flags: c_int) -> c_int;
    pub fn nng_msg_alloc(msg: *mut *mut NngMsg, size: usize) -> c_int;
    pub fn nng_msg_free(msg: *mut NngMsg);
    pub fn nng_msg_body(msg: *mut NngMsg) -> *mut c_void;
    pub fn nng_msg_len(msg: *mut NngMsg) -> usize;
    pub fn nng_msg_header(msg: *mut NngMsg) -> *mut c_void;
    pub fn nng_msg_header_len(msg: *mut NngMsg) -> usize;
    pub fn nng_msg_append(msg: *mut NngMsg, data: *const c_void, size: usize) -> c_int;
    pub fn nng_msg_dup(dup: *mut *mut NngMsg, orig: *const NngMsg) -> c_int;
    pub fn nng_msg_header_append(msg: *mut NngMsg, data: *const c_void, size: usize) -> c_int;
    pub fn nng_msg_header_insert(msg: *mut NngMsg, data: *const c_void, size: usize) -> c_int;
    pub fn nng_msg_header_clear(msg: *mut NngMsg);
    pub fn nng_msg_header_trim(msg: *mut NngMsg, size: usize) -> c_int;
    pub fn nng_msg_clear(msg: *mut NngMsg);

    // Device
    pub fn nng_device(s1: NngSocket, s2: NngSocket) -> c_int;

    // Options — typed getters
    pub fn nng_socket_get_int(socket: NngSocket, opt: *const c_char, val: *mut c_int) -> c_int;
    pub fn nng_socket_get_ms(socket: NngSocket, opt: *const c_char, val: *mut i32) -> c_int;
    pub fn nng_socket_get_size(socket: NngSocket, opt: *const c_char, val: *mut usize) -> c_int;
    pub fn nng_socket_get_string(
        socket: NngSocket,
        opt: *const c_char,
        val: *mut *mut c_char,
    ) -> c_int;

    // Options — typed setters
    pub fn nng_socket_set(
        socket: NngSocket,
        opt: *const c_char,
        data: *const c_void,
        size: usize,
    ) -> c_int;
    pub fn nng_socket_set_int(socket: NngSocket, opt: *const c_char, val: c_int) -> c_int;
    pub fn nng_socket_set_ms(socket: NngSocket, opt: *const c_char, val: i32) -> c_int;
    pub fn nng_socket_set_size(socket: NngSocket, opt: *const c_char, val: usize) -> c_int;
    pub fn nng_socket_set_string(
        socket: NngSocket,
        opt: *const c_char,
        val: *const c_char,
    ) -> c_int;

    // String management
    pub fn nng_strfree(str: *mut c_char);
}
