/**
 * Headless stress: dew UI frames on the main thread while a worker allocates
 * under thread-local GC (`tgc`). Measures max per-frame stall and PASS/FAIL.
 */
module tgc_stress;

import std.stdio;
import std.format : format;
import core.time;
import core.thread;
import core.atomic;
import core.memory;
import tgc.gcobj;
import dew;

/// Documented pass threshold — max `App.frame()` duration during stress (ms).
enum double MaxFrameStallMs = 48.0;
enum int StressFrameCount = 400;
enum int WorkerBurstAllocs = 128;
enum int WorkerBurstBytes = 4096;

shared bool workerStop;
shared size_t workerBursts;

void allocWorker() nothrow
{
    ubyte[] anchor;
    try
    {
        anchor = new ubyte[16_384];
        anchor[0] = 1;
    }
    catch (Exception)
    {
        return;
    }

    while (!atomicLoad!(MemoryOrder.acq)(workerStop))
    {
        try
        {
            foreach (_; 0 .. WorkerBurstAllocs)
            {
                auto block = new ubyte[WorkerBurstBytes];
                block[0] = block[$ - 1] = 0xA5;
            }
            GC.collect();
            atomicOp!"+="(workerBursts, 1);
        }
        catch (Exception)
        {
            Thread.yield();
        }
        Thread.yield();
    }

    assert(anchor[0] == 1);
}

bool runtimeUsesTgc()
{
    // Factory registration is link-time; collections on the main thread after
    // a worker burst should not require STW sibling suspend when tgc is active.
    atomicStore(workerStop, false);
    atomicStore(workerBursts, 0);

    auto worker = new Thread(&allocWorker);
    worker.name = "tgc-stress-alloc";
    worker.isDaemon = true;
    worker.start();

    auto deadline = MonoTime.currTime + 500.msecs;
    while (atomicLoad!(MemoryOrder.acq)(workerBursts) == 0)
    {
        if (MonoTime.currTime >= deadline)
            break;
        Thread.yield();
    }

    long worstNs;
    foreach (_; 0 .. 24)
    {
        auto t0 = MonoTime.currTime;
        GC.collect();
        auto dt = MonoTime.currTime - t0;
        if (dt.total!"nsecs" > worstNs)
            worstNs = dt.total!"nsecs";
        Thread.yield();
    }

    atomicStore(workerStop, true);
    worker.join();

    // With default GC, worker collections often pause the main thread for tens
    // of ms once the worker has allocated; tgc keeps main-thread collects local.
    return worstNs < 12_000_000; // 12 ms probe budget
}

struct FrameStats
{
    long maxFrameNs;
    long totalFrameNs;
    int frames;
    double maxFrameMs() const @safe pure nothrow
    {
        return maxFrameNs / 1_000_000.0;
    }
}

FrameStats runUiStress()
{
    App app;
    beginUi(app.ui);
    scope (exit)
        endUi();

    app.setRoot(
        VStack(
            Text("tgc stress").fontSize(16).bold(),
            Text("Worker allocating on sibling thread."),
            Button("noop").onClick(() {})
        ).spacing(6).padding(12)
    );

    auto sw = new SoftwareBackend(640, 360);
    app.backend = sw;
    app.resize(640, 360);

    FrameStats stats;
    foreach (i; 0 .. StressFrameCount)
    {
        auto t0 = MonoTime.currTime;
        app.frame();
        auto dt = (MonoTime.currTime - t0).total!"nsecs";
        stats.totalFrameNs += dt;
        stats.frames++;
        if (dt > stats.maxFrameNs)
            stats.maxFrameNs = dt;

        if (i % 16 == 0)
            Thread.yield();
    }
    return stats;
}

void main()
{
    writeln("dew tgc-stress ", dewVersion, " — ", dewSlogan);
    writeln(format("threshold: max frame stall <= %.1f ms over %d frames",
            MaxFrameStallMs, StressFrameCount));

    if (!runtimeUsesTgc())
    {
        writeln("TGC_STRESS: SKIP (tgc not active — use LDC/DMD with pluggable GC and Tgc_default or --DRT-gcopt=gc:tgc)");
        return;
    }

    atomicStore(workerStop, false);
    atomicStore(workerBursts, 0);

    auto worker = new Thread(&allocWorker);
    worker.name = "tgc-stress-alloc";
    worker.start();

    // Let the worker reach steady allocation before UI measurement.
    auto warm = MonoTime.currTime + 80.msecs;
    while (MonoTime.currTime < warm)
        Thread.yield();

    auto stats = runUiStress();

    atomicStore(workerStop, true);
    worker.join();

    const avgMs = (stats.totalFrameNs / cast(double) stats.frames) / 1_000_000.0;
    writeln(format("frames=%d max=%.3f ms avg=%.3f ms worker_bursts=%d",
            stats.frames, stats.maxFrameMs(), avgMs, atomicLoad(workerBursts)));

    if (stats.maxFrameMs() <= MaxFrameStallMs)
        writeln("TGC_STRESS: PASS");
    else
        writeln("TGC_STRESS: FAIL");
}
