/// Contiguous bump allocator for UI frame / tree storage.
module rmgui.arena;

import core.stdc.stdlib : malloc, free, realloc;
import core.stdc.string : memcpy, memset;

/// Linear arena; reset between frames or rebuilds. Not thread-safe.
struct Arena
{
    ubyte* base;
    size_t capacity;
    size_t used;

    @disable this(this);

    void reserve(size_t bytes) @trusted nothrow
    {
        if (bytes <= capacity)
            return;
        size_t ncap = capacity ? capacity : 4096;
        while (ncap < bytes)
            ncap *= 2;
        auto nb = cast(ubyte*) realloc(base, ncap);
        if (!nb)
            assert(0, "Arena.reserve OOM");
        base = nb;
        capacity = ncap;
    }

    void* alloc(size_t bytes, size_t align_ = (void*).sizeof) @trusted nothrow
    {
        size_t pad = (align_ - (used % align_)) % align_;
        size_t need = used + pad + bytes;
        reserve(need);
        used += pad;
        void* p = base + used;
        used += bytes;
        return p;
    }

    T* make(T)(auto ref T value) @trusted nothrow
    {
        auto p = cast(T*) alloc(T.sizeof, T.alignof);
        *p = value;
        return p;
    }

    char[] dupString(const(char)[] s) @trusted nothrow
    {
        if (!s.length)
            return null;
        auto p = cast(char*) alloc(s.length, 1);
        memcpy(p, s.ptr, s.length);
        return p[0 .. s.length];
    }

    void reset() @safe @nogc nothrow
    {
        used = 0;
    }

    void dispose() @trusted nothrow
    {
        if (base)
            free(base);
        base = null;
        capacity = 0;
        used = 0;
    }

    ~this() @trusted
    {
        dispose();
    }
}
