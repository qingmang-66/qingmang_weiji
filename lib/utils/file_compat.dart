import 'file_compat_stub.dart'
    if (dart.library.io) 'file_compat_io.dart'
    if (dart.library.html) 'file_compat_web.dart' as impl;

typedef AppFile = impl.AppFile;
