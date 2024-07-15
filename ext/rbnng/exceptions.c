/*
 * Copyright (c) 2021 Adib Saad
 *
 */
#include "rbnng.h"
#include <nng/nng.h>
#include <ruby.h>

VALUE rbnng_eBase = Qnil;

VALUE rbnng_eInterrupted = Qnil;
VALUE rbnng_eOutOfMemory = Qnil;
VALUE rbnng_eInvalidArgument = Qnil;
VALUE rbnng_eResourceBusy = Qnil;
VALUE rbnng_eTimedOut = Qnil;
VALUE rbnng_eConnectionRefused = Qnil;
VALUE rbnng_eObjectClosed = Qnil;
VALUE rbnng_eTryAgain = Qnil;
VALUE rbnng_eNotSupported = Qnil;
VALUE rbnng_eAddressInUse = Qnil;
VALUE rbnng_eIncorrectState = Qnil;
VALUE rbnng_eEntryNotFound = Qnil;
VALUE rbnng_eProtocolError = Qnil;
VALUE rbnng_eDestinationUnreachable = Qnil;
VALUE rbnng_eAddressInvalid = Qnil;
VALUE rbnng_ePermissionDenied = Qnil;
VALUE rbnng_eMessageTooLarge = Qnil;
VALUE rbnng_eConnectionReset = Qnil;
VALUE rbnng_eConnectionAborted = Qnil;
VALUE rbnng_eOperationCanceled = Qnil;
VALUE rbnng_eOutOfFiles = Qnil;
VALUE rbnng_eOutOfSpace = Qnil;
VALUE rbnng_eResourceAlreadyExists = Qnil;
VALUE rbnng_eReadOnlyResource = Qnil;
VALUE rbnng_eWriteOnlyResource = Qnil;
VALUE rbnng_eCryptographicError = Qnil;
VALUE rbnng_ePeerCouldNotBeAuthenticated = Qnil;
VALUE rbnng_eOptionRequiresArgument = Qnil;
VALUE rbnng_eAmbiguousOption = Qnil;
VALUE rbnng_eIncorrectType = Qnil;
VALUE rbnng_eConnectionShutdown = Qnil;
VALUE rbnng_eInternalErrorDetected = Qnil;

void
rbnng_exceptions_Init(void)
{
  VALUE errorModule = rb_define_module_under(rbnng_Module, "Error");
  rbnng_eBase = rb_define_class_under(errorModule, "Error", rb_eRuntimeError);

  rbnng_eInterrupted =
    rb_define_class_under(errorModule, "Interrupted", rbnng_eBase);
  rbnng_eOutOfMemory =
    rb_define_class_under(errorModule, "OutOfMemory", rbnng_eBase);
  rbnng_eInvalidArgument =
    rb_define_class_under(errorModule, "InvalidArgument", rbnng_eBase);
  rbnng_eResourceBusy =
    rb_define_class_under(errorModule, "ResourceBusy", rbnng_eBase);
  rbnng_eTimedOut = rb_define_class_under(errorModule, "TimedOut", rbnng_eBase);
  rbnng_eConnectionRefused =
    rb_define_class_under(errorModule, "ConnectionRefused", rbnng_eBase);
  rbnng_eObjectClosed =
    rb_define_class_under(errorModule, "ObjectClosed", rbnng_eBase);
  rbnng_eTryAgain = rb_define_class_under(errorModule, "TryAgain", rbnng_eBase);
  rbnng_eNotSupported =
    rb_define_class_under(errorModule, "NotSupported", rbnng_eBase);
  rbnng_eAddressInUse =
    rb_define_class_under(errorModule, "AddressInUse", rbnng_eBase);
  rbnng_eIncorrectState =
    rb_define_class_under(errorModule, "IncorrectState", rbnng_eBase);
  rbnng_eEntryNotFound =
    rb_define_class_under(errorModule, "EntryNotFound", rbnng_eBase);
  rbnng_eProtocolError =
    rb_define_class_under(errorModule, "ProtocolError", rbnng_eBase);
  rbnng_eDestinationUnreachable =
    rb_define_class_under(errorModule, "DestinationUnreachable", rbnng_eBase);
  rbnng_eAddressInvalid =
    rb_define_class_under(errorModule, "AddressInvalid", rbnng_eBase);
  rbnng_ePermissionDenied =
    rb_define_class_under(errorModule, "PermissionDenied", rbnng_eBase);
  rbnng_eMessageTooLarge =
    rb_define_class_under(errorModule, "MessageTooLarge", rbnng_eBase);
  rbnng_eConnectionReset =
    rb_define_class_under(errorModule, "ConnectionReset", rbnng_eBase);
  rbnng_eConnectionAborted =
    rb_define_class_under(errorModule, "ConnectionAborted", rbnng_eBase);
  rbnng_eOperationCanceled =
    rb_define_class_under(errorModule, "OperationCanceled", rbnng_eBase);
  rbnng_eOutOfFiles =
    rb_define_class_under(errorModule, "OutOfFiles", rbnng_eBase);
  rbnng_eOutOfSpace =
    rb_define_class_under(errorModule, "OutOfSpace", rbnng_eBase);
  rbnng_eResourceAlreadyExists =
    rb_define_class_under(errorModule, "ResourceAlreadyExists", rbnng_eBase);
  rbnng_eReadOnlyResource =
    rb_define_class_under(errorModule, "ReadOnlyResource", rbnng_eBase);
  rbnng_eWriteOnlyResource =
    rb_define_class_under(errorModule, "WriteOnlyResource", rbnng_eBase);
  rbnng_eCryptographicError =
    rb_define_class_under(errorModule, "CryptographicError", rbnng_eBase);
  rbnng_ePeerCouldNotBeAuthenticated = rb_define_class_under(
    errorModule, "PeerCouldNotBeAuthenticated", rbnng_eBase);
  rbnng_eOptionRequiresArgument =
    rb_define_class_under(errorModule, "OptionRequiresArgument", rbnng_eBase);
  rbnng_eAmbiguousOption =
    rb_define_class_under(errorModule, "AmbiguousOption", rbnng_eBase);
  rbnng_eIncorrectType =
    rb_define_class_under(errorModule, "IncorrectType", rbnng_eBase);
  rbnng_eConnectionShutdown =
    rb_define_class_under(errorModule, "ConnectionShutdown", rbnng_eBase);
  rbnng_eInternalErrorDetected =
    rb_define_class_under(errorModule, "InternalErrorDetected", rbnng_eBase);
}

void
raise_error(int nng_errno)
{
  switch (nng_errno) {
    case NNG_EINTR:
      rb_raise(rbnng_eInterrupted, "");
      break;
    case NNG_ENOMEM:
      rb_raise(rbnng_eOutOfMemory, "");
      break;
    case NNG_EINVAL:
      rb_raise(rbnng_eInvalidArgument, "");
      break;
    case NNG_EBUSY:
      rb_raise(rbnng_eResourceBusy, "");
      break;
    case NNG_ETIMEDOUT:
      rb_raise(rbnng_eTimedOut, "");
      break;
    case NNG_ECONNREFUSED:
      rb_raise(rbnng_eConnectionRefused, "");
      break;
    case NNG_ECLOSED:
      rb_raise(rbnng_eObjectClosed, "");
      break;
    case NNG_EAGAIN:
      rb_raise(rbnng_eTryAgain, "");
      break;
    case NNG_ENOTSUP:
      rb_raise(rbnng_eNotSupported, "");
      break;
    case NNG_EADDRINUSE:
      rb_raise(rbnng_eAddressInUse, "");
      break;
    case NNG_ESTATE:
      rb_raise(rbnng_eIncorrectState, "");
      break;
    case NNG_ENOENT:
      rb_raise(rbnng_eEntryNotFound, "");
      break;
    case NNG_EPROTO:
      rb_raise(rbnng_eProtocolError, "");
      break;
    case NNG_EUNREACHABLE:
      rb_raise(rbnng_eDestinationUnreachable, "");
      break;
    case NNG_EADDRINVAL:
      rb_raise(rbnng_eAddressInvalid, "");
      break;
    case NNG_EPERM:
      rb_raise(rbnng_ePermissionDenied, "");
      break;
    case NNG_EMSGSIZE:
      rb_raise(rbnng_eMessageTooLarge, "");
      break;
    case NNG_ECONNRESET:
      rb_raise(rbnng_eConnectionReset, "");
      break;
    case NNG_ECONNABORTED:
      rb_raise(rbnng_eConnectionAborted, "");
      break;
    case NNG_ECANCELED:
      rb_raise(rbnng_eOperationCanceled, "");
      break;
    case NNG_ENOFILES:
      rb_raise(rbnng_eOutOfFiles, "");
      break;
    case NNG_ENOSPC:
      rb_raise(rbnng_eOutOfSpace, "");
      break;
    case NNG_EEXIST:
      rb_raise(rbnng_eResourceAlreadyExists, "");
      break;
    case NNG_EREADONLY:
      rb_raise(rbnng_eReadOnlyResource, "");
      break;
    case NNG_EWRITEONLY:
      rb_raise(rbnng_eWriteOnlyResource, "");
      break;
    case NNG_ECRYPTO:
      rb_raise(rbnng_eCryptographicError, "");
      break;
    case NNG_EPEERAUTH:
      rb_raise(rbnng_ePeerCouldNotBeAuthenticated, "");
      break;
    case NNG_ENOARG:
      rb_raise(rbnng_eOptionRequiresArgument, "");
      break;
    case NNG_EAMBIGUOUS:
      rb_raise(rbnng_eAmbiguousOption, "");
      break;
    case NNG_EBADTYPE:
      rb_raise(rbnng_eIncorrectType, "");
      break;
    case NNG_ECONNSHUT:
      rb_raise(rbnng_eConnectionShutdown, "");
      break;
    case NNG_EINTERNAL:
      rb_raise(rbnng_eInternalErrorDetected, "");
      break;
    default:
      rb_raise(rbnng_eBase, "errno %d, %s", nng_errno, nng_strerror(nng_errno));
      break;
  }
}
