/// Lightweight reactive signal with dirty-flag subscribers.
module rmgui.signal;

/// Observer callback — keep `@nogc` when possible on the UI thread.
alias SignalListener = void delegate() @safe;

/**
 * Reactive cell. Assigning notifies listeners so layout/paint can invalidate
 * only dirty subtrees rather than rebuilding the whole tree.
 */
struct Signal(T)
{
    private T _value;
    private SignalListener[] _listeners;
    private bool _dirty;

    this(T initial) @safe nothrow
    {
        _value = initial;
    }

    @property T value() const @safe @nogc pure nothrow
    {
        return _value;
    }

    @property void value(T v) @safe
    {
        if (_value == v)
            return;
        _value = v;
        _dirty = true;
        notify();
    }

    void opAssign(T v) @safe
    {
        value = v;
    }

    void subscribe(SignalListener l) @safe nothrow
    {
        _listeners ~= l;
    }

    bool takeDirty() @safe @nogc nothrow
    {
        const d = _dirty;
        _dirty = false;
        return d;
    }

    private void notify() @safe
    {
        foreach (l; _listeners)
            if (l !is null)
                l();
    }
}
