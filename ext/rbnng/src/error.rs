use magnus::{value::Lazy, Error, ExceptionClass, Module, RModule, Ruby};

use crate::ffi;

static E_BASE: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "Error"));
static E_INTERRUPTED: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "Interrupted"));
static E_OUT_OF_MEMORY: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "OutOfMemory"));
static E_INVALID_ARGUMENT: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "InvalidArgument"));
static E_RESOURCE_BUSY: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "ResourceBusy"));
static E_TIMED_OUT: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "TimedOut"));
static E_CONNECTION_REFUSED: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ConnectionRefused"));
static E_OBJECT_CLOSED: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "ObjectClosed"));
static E_TRY_AGAIN: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "TryAgain"));
static E_NOT_SUPPORTED: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "NotSupported"));
static E_ADDRESS_IN_USE: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "AddressInUse"));
static E_INCORRECT_STATE: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "IncorrectState"));
static E_ENTRY_NOT_FOUND: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "EntryNotFound"));
static E_PROTOCOL_ERROR: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "ProtocolError"));
static E_DESTINATION_UNREACHABLE: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "DestinationUnreachable"));
static E_ADDRESS_INVALID: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "AddressInvalid"));
static E_PERMISSION_DENIED: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "PermissionDenied"));
static E_MESSAGE_TOO_LARGE: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "MessageTooLarge"));
static E_CONNECTION_ABORTED: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ConnectionAborted"));
static E_CONNECTION_RESET: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ConnectionReset"));
static E_OPERATION_CANCELED: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "OperationCanceled"));
static E_OUT_OF_FILES: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "OutOfFiles"));
static E_OUT_OF_SPACE: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "OutOfSpace"));
static E_RESOURCE_ALREADY_EXISTS: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ResourceAlreadyExists"));
static E_READ_ONLY_RESOURCE: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ReadOnlyResource"));
static E_WRITE_ONLY_RESOURCE: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "WriteOnlyResource"));
static E_CRYPTOGRAPHIC_ERROR: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "CryptographicError"));
static E_PEER_AUTH: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "PeerCouldNotBeAuthenticated"));
static E_OPTION_REQUIRES_ARGUMENT: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "OptionRequiresArgument"));
static E_AMBIGUOUS_OPTION: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "AmbiguousOption"));
static E_INCORRECT_TYPE: Lazy<ExceptionClass> = Lazy::new(|ruby| get_class(ruby, "IncorrectType"));
static E_CONNECTION_SHUTDOWN: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "ConnectionShutdown"));
static E_INTERNAL_ERROR: Lazy<ExceptionClass> =
    Lazy::new(|ruby| get_class(ruby, "InternalErrorDetected"));

fn get_class(ruby: &Ruby, name: &str) -> ExceptionClass {
    let nng_mod: RModule = ruby.define_module("NNG").expect("NNG");
    let error: RModule = nng_mod.define_module("Error").expect("NNG::Error");
    error.const_get(name).expect(name)
}

pub fn nng_error(ruby: &Ruby, rv: i32) -> Error {
    let msg = unsafe {
        let ptr = ffi::nng_strerror(rv);
        std::ffi::CStr::from_ptr(ptr).to_string_lossy().into_owned()
    };
    let cls = match rv {
        ffi::NNG_EINTR => ruby.get_inner(&E_INTERRUPTED),
        ffi::NNG_ENOMEM => ruby.get_inner(&E_OUT_OF_MEMORY),
        ffi::NNG_EINVAL => ruby.get_inner(&E_INVALID_ARGUMENT),
        ffi::NNG_EBUSY => ruby.get_inner(&E_RESOURCE_BUSY),
        ffi::NNG_ETIMEDOUT => ruby.get_inner(&E_TIMED_OUT),
        ffi::NNG_ECONNREFUSED => ruby.get_inner(&E_CONNECTION_REFUSED),
        ffi::NNG_ECLOSED => ruby.get_inner(&E_OBJECT_CLOSED),
        ffi::NNG_EAGAIN => ruby.get_inner(&E_TRY_AGAIN),
        ffi::NNG_ENOTSUP => ruby.get_inner(&E_NOT_SUPPORTED),
        ffi::NNG_EADDRINUSE => ruby.get_inner(&E_ADDRESS_IN_USE),
        ffi::NNG_ESTATE => ruby.get_inner(&E_INCORRECT_STATE),
        ffi::NNG_ENOENT => ruby.get_inner(&E_ENTRY_NOT_FOUND),
        ffi::NNG_EPROTO => ruby.get_inner(&E_PROTOCOL_ERROR),
        ffi::NNG_EUNREACHABLE => ruby.get_inner(&E_DESTINATION_UNREACHABLE),
        ffi::NNG_EADDRINVAL => ruby.get_inner(&E_ADDRESS_INVALID),
        ffi::NNG_EPERM => ruby.get_inner(&E_PERMISSION_DENIED),
        ffi::NNG_EMSGSIZE => ruby.get_inner(&E_MESSAGE_TOO_LARGE),
        ffi::NNG_ECONNABORTED => ruby.get_inner(&E_CONNECTION_ABORTED),
        ffi::NNG_ECONNRESET => ruby.get_inner(&E_CONNECTION_RESET),
        ffi::NNG_ECANCELED => ruby.get_inner(&E_OPERATION_CANCELED),
        ffi::NNG_ENOFILES => ruby.get_inner(&E_OUT_OF_FILES),
        ffi::NNG_ENOSPC => ruby.get_inner(&E_OUT_OF_SPACE),
        ffi::NNG_EEXIST => ruby.get_inner(&E_RESOURCE_ALREADY_EXISTS),
        ffi::NNG_EREADONLY => ruby.get_inner(&E_READ_ONLY_RESOURCE),
        ffi::NNG_EWRITEONLY => ruby.get_inner(&E_WRITE_ONLY_RESOURCE),
        ffi::NNG_ECRYPTO => ruby.get_inner(&E_CRYPTOGRAPHIC_ERROR),
        ffi::NNG_EPEERAUTH => ruby.get_inner(&E_PEER_AUTH),
        ffi::NNG_ENOARG => ruby.get_inner(&E_OPTION_REQUIRES_ARGUMENT),
        ffi::NNG_EAMBIGUOUS => ruby.get_inner(&E_AMBIGUOUS_OPTION),
        ffi::NNG_EBADTYPE => ruby.get_inner(&E_INCORRECT_TYPE),
        ffi::NNG_ECONNSHUT => ruby.get_inner(&E_CONNECTION_SHUTDOWN),
        ffi::NNG_EINTERNAL => ruby.get_inner(&E_INTERNAL_ERROR),
        _ => ruby.get_inner(&E_BASE),
    };
    Error::new(cls, msg)
}

pub fn init(ruby: &Ruby, nng_mod: RModule) -> Result<(), Error> {
    let error = nng_mod.define_module("Error")?;
    let runtime_error: magnus::RClass = ruby.eval("RuntimeError")?;
    let base = error.define_class("Error", runtime_error)?;
    error.define_class("Interrupted", base)?;
    error.define_class("OutOfMemory", base)?;
    error.define_class("InvalidArgument", base)?;
    error.define_class("ResourceBusy", base)?;
    error.define_class("TimedOut", base)?;
    error.define_class("ConnectionRefused", base)?;
    error.define_class("ObjectClosed", base)?;
    error.define_class("TryAgain", base)?;
    error.define_class("NotSupported", base)?;
    error.define_class("AddressInUse", base)?;
    error.define_class("IncorrectState", base)?;
    error.define_class("EntryNotFound", base)?;
    error.define_class("ProtocolError", base)?;
    error.define_class("DestinationUnreachable", base)?;
    error.define_class("AddressInvalid", base)?;
    error.define_class("PermissionDenied", base)?;
    error.define_class("MessageTooLarge", base)?;
    error.define_class("ConnectionAborted", base)?;
    error.define_class("ConnectionReset", base)?;
    error.define_class("OperationCanceled", base)?;
    error.define_class("OutOfFiles", base)?;
    error.define_class("OutOfSpace", base)?;
    error.define_class("ResourceAlreadyExists", base)?;
    error.define_class("ReadOnlyResource", base)?;
    error.define_class("WriteOnlyResource", base)?;
    error.define_class("CryptographicError", base)?;
    error.define_class("PeerCouldNotBeAuthenticated", base)?;
    error.define_class("OptionRequiresArgument", base)?;
    error.define_class("AmbiguousOption", base)?;
    error.define_class("IncorrectType", base)?;
    error.define_class("ConnectionShutdown", base)?;
    error.define_class("InternalErrorDetected", base)?;
    Ok(())
}
