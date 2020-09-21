module ppl.config.Logging;

enum Logging : ulong {
    PARSE               = 1L<<0,
    RESOLVE             = 1L<<1,
    STATE               = 1L<<2,
    STATS               = 1L<<3,
    HEADER              = 1L<<4,
    DCE                 = 1L<<5,
    GENERATE            = 1L<<6,
    ID_TARGET_FINDER    = 1L<<7,
    LINKER              = 1L<<8,
}
