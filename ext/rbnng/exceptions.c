#include "rbnng.h"

static VALUE eBase;
static VALUE eInterrupted;
static VALUE eOutOfMemory;
static VALUE eInvalidArgument;
static VALUE eResourceBusy;
static VALUE eTimedOut;
static VALUE eConnectionRefused;
static VALUE eObjectClosed;
static VALUE eTryAgain;
static VALUE eNotSupported;
static VALUE eAddressInUse;
static VALUE eIncorrectState;
static VALUE eEntryNotFound;
static VALUE eProtocolError;
static VALUE eDestinationUnreachable;
static VALUE eAddressInvalid;
static VALUE ePermissionDenied;
static VALUE eMessageTooLarge;
static VALUE eConnectionAborted;
static VALUE eConnectionReset;
static VALUE eOperationCanceled;
static VALUE eOutOfFiles;
static VALUE eOutOfSpace;
static VALUE eResourceAlreadyExists;
static VALUE eReadOnlyResource;
static VALUE eWriteOnlyResource;
static VALUE eCryptographicError;
static VALUE ePeerCouldNotBeAuthenticated;
static VALUE eOptionRequiresArgument;
static VALUE eAmbiguousOption;
static VALUE eIncorrectType;
static VALUE eConnectionShutdown;
static VALUE eInternalErrorDetected;

void
raise_nng_error(int rv)
{
    const char *msg = nng_strerror(rv);
    VALUE cls;

    switch (rv) {
    case NNG_EINTR:        cls = eInterrupted; break;
    case NNG_ENOMEM:       cls = eOutOfMemory; break;
    case NNG_EINVAL:       cls = eInvalidArgument; break;
    case NNG_EBUSY:        cls = eResourceBusy; break;
    case NNG_ETIMEDOUT:    cls = eTimedOut; break;
    case NNG_ECONNREFUSED: cls = eConnectionRefused; break;
    case NNG_ECLOSED:      cls = eObjectClosed; break;
    case NNG_EAGAIN:       cls = eTryAgain; break;
    case NNG_ENOTSUP:      cls = eNotSupported; break;
    case NNG_EADDRINUSE:   cls = eAddressInUse; break;
    case NNG_ESTATE:       cls = eIncorrectState; break;
    case NNG_ENOENT:       cls = eEntryNotFound; break;
    case NNG_EPROTO:       cls = eProtocolError; break;
    case NNG_EUNREACHABLE: cls = eDestinationUnreachable; break;
    case NNG_EADDRINVAL:   cls = eAddressInvalid; break;
    case NNG_EPERM:        cls = ePermissionDenied; break;
    case NNG_EMSGSIZE:     cls = eMessageTooLarge; break;
    case NNG_ECONNABORTED: cls = eConnectionAborted; break;
    case NNG_ECONNRESET:   cls = eConnectionReset; break;
    case NNG_ECANCELED:    cls = eOperationCanceled; break;
    case NNG_ENOFILES:     cls = eOutOfFiles; break;
    case NNG_ENOSPC:       cls = eOutOfSpace; break;
    case NNG_EEXIST:       cls = eResourceAlreadyExists; break;
    case NNG_EREADONLY:    cls = eReadOnlyResource; break;
    case NNG_EWRITEONLY:   cls = eWriteOnlyResource; break;
    case NNG_ECRYPTO:      cls = eCryptographicError; break;
    case NNG_EPEERAUTH:    cls = ePeerCouldNotBeAuthenticated; break;
    case NNG_ENOARG:       cls = eOptionRequiresArgument; break;
    case NNG_EAMBIGUOUS:   cls = eAmbiguousOption; break;
    case NNG_EBADTYPE:     cls = eIncorrectType; break;
    case NNG_ECONNSHUT:    cls = eConnectionShutdown; break;
    case NNG_EINTERNAL:    cls = eInternalErrorDetected; break;
    default:               cls = eBase; break;
    }

    rb_raise(cls, "%s", msg);
}

#define DEF_ERR(var, mod, name) \
    var = rb_define_class_under(mod, name, eBase); \
    rb_gc_register_mark_object(var)

void
rbnng_exceptions_init(VALUE nng_module)
{
    VALUE m = rb_define_module_under(nng_module, "Error");

    eBase = rb_define_class_under(m, "Error", rb_eRuntimeError);
    rb_gc_register_mark_object(eBase);

    DEF_ERR(eInterrupted,                m, "Interrupted");
    DEF_ERR(eOutOfMemory,                m, "OutOfMemory");
    DEF_ERR(eInvalidArgument,            m, "InvalidArgument");
    DEF_ERR(eResourceBusy,               m, "ResourceBusy");
    DEF_ERR(eTimedOut,                   m, "TimedOut");
    DEF_ERR(eConnectionRefused,          m, "ConnectionRefused");
    DEF_ERR(eObjectClosed,               m, "ObjectClosed");
    DEF_ERR(eTryAgain,                   m, "TryAgain");
    DEF_ERR(eNotSupported,               m, "NotSupported");
    DEF_ERR(eAddressInUse,               m, "AddressInUse");
    DEF_ERR(eIncorrectState,             m, "IncorrectState");
    DEF_ERR(eEntryNotFound,              m, "EntryNotFound");
    DEF_ERR(eProtocolError,              m, "ProtocolError");
    DEF_ERR(eDestinationUnreachable,     m, "DestinationUnreachable");
    DEF_ERR(eAddressInvalid,             m, "AddressInvalid");
    DEF_ERR(ePermissionDenied,           m, "PermissionDenied");
    DEF_ERR(eMessageTooLarge,            m, "MessageTooLarge");
    DEF_ERR(eConnectionAborted,          m, "ConnectionAborted");
    DEF_ERR(eConnectionReset,            m, "ConnectionReset");
    DEF_ERR(eOperationCanceled,          m, "OperationCanceled");
    DEF_ERR(eOutOfFiles,                 m, "OutOfFiles");
    DEF_ERR(eOutOfSpace,                 m, "OutOfSpace");
    DEF_ERR(eResourceAlreadyExists,      m, "ResourceAlreadyExists");
    DEF_ERR(eReadOnlyResource,           m, "ReadOnlyResource");
    DEF_ERR(eWriteOnlyResource,          m, "WriteOnlyResource");
    DEF_ERR(eCryptographicError,         m, "CryptographicError");
    DEF_ERR(ePeerCouldNotBeAuthenticated,m, "PeerCouldNotBeAuthenticated");
    DEF_ERR(eOptionRequiresArgument,     m, "OptionRequiresArgument");
    DEF_ERR(eAmbiguousOption,            m, "AmbiguousOption");
    DEF_ERR(eIncorrectType,              m, "IncorrectType");
    DEF_ERR(eConnectionShutdown,         m, "ConnectionShutdown");
    DEF_ERR(eInternalErrorDetected,      m, "InternalErrorDetected");
}
