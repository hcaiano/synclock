// AbletonLinkBridge — real Ableton Link C ABI wrapper.
//
// This file keeps C++ templates and ableton::Link out of Swift. The exported
// API in include/AbletonLinkBridge.h is intentionally stable; Swift code owns
// application semantics while this bridge owns the Link session object.
//
// GPLv2-or-later. Synclock.

#include "AbletonLinkBridge.h"

#include <ableton/Link.hpp>

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>

namespace {

std::chrono::microseconds micros(int64_t value) {
    return std::chrono::microseconds(value);
}

int64_t count(std::chrono::microseconds value) {
    return static_cast<int64_t>(value.count());
}

} // namespace

struct MCLinkRef {
    explicit MCLinkRef(double initialBPM)
        : link(std::make_unique<ableton::Link>(initialBPM)) {
        link->setNumPeersCallback([this](std::size_t peers) { notifyPeerCount(peers); });
        link->setTempoCallback([this](double bpm) { notifyTempo(bpm); });
        link->setStartStopCallback([this](bool isPlaying) { notifyStartStop(isPlaying); });
    }

    ~MCLinkRef() {
        link->enable(false);
        link->setNumPeersCallback([](std::size_t) {});
        link->setTempoCallback([](double) {});
        link->setStartStopCallback([](bool) {});
    }

    std::unique_ptr<ableton::Link> link;

    std::mutex callbackMutex;
    void *peerCtx = nullptr;
    void *tempoCtx = nullptr;
    void *startStopCtx = nullptr;
    MCLinkPeerCountCallback peerCb = nullptr;
    MCLinkTempoCallback tempoCb = nullptr;
    MCLinkStartStopCallback startStopCb = nullptr;

    void notifyPeerCount(std::size_t peers) {
        MCLinkPeerCountCallback cb = nullptr;
        void *ctx = nullptr;
        {
            std::lock_guard<std::mutex> lock(callbackMutex);
            cb = peerCb;
            ctx = peerCtx;
        }
        if (cb) cb(ctx, static_cast<uint32_t>(peers));
    }

    void notifyTempo(double bpm) {
        MCLinkTempoCallback cb = nullptr;
        void *ctx = nullptr;
        {
            std::lock_guard<std::mutex> lock(callbackMutex);
            cb = tempoCb;
            ctx = tempoCtx;
        }
        if (cb) cb(ctx, bpm);
    }

    void notifyStartStop(bool isPlaying) {
        MCLinkStartStopCallback cb = nullptr;
        void *ctx = nullptr;
        {
            std::lock_guard<std::mutex> lock(callbackMutex);
            cb = startStopCb;
            ctx = startStopCtx;
        }
        if (cb) cb(ctx, isPlaying);
    }
};

extern "C" {

MCLinkRef *MCLinkCreate(double initialBPM) {
    return new MCLinkRef(initialBPM);
}

void MCLinkDestroy(MCLinkRef *link) {
    delete link;
}

void MCLinkSetEnabled(MCLinkRef *link, bool enabled) {
    link->link->enable(enabled);
}

bool MCLinkIsEnabled(MCLinkRef *link) {
    return link->link->isEnabled();
}

void MCLinkSetStartStopSyncEnabled(MCLinkRef *link, bool enabled) {
    link->link->enableStartStopSync(enabled);
}

bool MCLinkIsStartStopSyncEnabled(MCLinkRef *link) {
    return link->link->isStartStopSyncEnabled();
}

uint32_t MCLinkPeerCount(MCLinkRef *link) {
    return static_cast<uint32_t>(link->link->numPeers());
}

double MCLinkTempo(MCLinkRef *link) {
    return link->link->captureAppSessionState().tempo();
}

void MCLinkSetTempo(MCLinkRef *link, double bpm, int64_t hostMicros) {
    auto state = link->link->captureAppSessionState();
    state.setTempo(bpm, micros(hostMicros));
    link->link->commitAppSessionState(state);
}

double MCLinkBeatAtTime(MCLinkRef *link, int64_t hostMicros, double quantum) {
    return link->link->captureAppSessionState().beatAtTime(micros(hostMicros), quantum);
}

double MCLinkPhaseAtTime(MCLinkRef *link, int64_t hostMicros, double quantum) {
    return link->link->captureAppSessionState().phaseAtTime(micros(hostMicros), quantum);
}

int64_t MCLinkTimeAtBeat(MCLinkRef *link, double beat, double quantum) {
    return count(link->link->captureAppSessionState().timeAtBeat(beat, quantum));
}

void MCLinkRequestBeatAtTime(MCLinkRef *link, double beat, int64_t hostMicros, double quantum) {
    auto state = link->link->captureAppSessionState();
    state.requestBeatAtTime(beat, micros(hostMicros), quantum);
    link->link->commitAppSessionState(state);
}

bool MCLinkIsPlaying(MCLinkRef *link) {
    return link->link->captureAppSessionState().isPlaying();
}

int64_t MCLinkTimeForIsPlaying(MCLinkRef *link) {
    return count(link->link->captureAppSessionState().timeForIsPlaying());
}

void MCLinkSetIsPlaying(MCLinkRef *link, bool playing, int64_t hostMicros) {
    auto state = link->link->captureAppSessionState();
    state.setIsPlaying(playing, micros(hostMicros));
    link->link->commitAppSessionState(state);
}

void MCLinkSetIsPlayingAndRequestBeatAtTime(MCLinkRef *link,
                                            bool playing,
                                            int64_t hostMicros,
                                            double beat,
                                            double quantum) {
    auto state = link->link->captureAppSessionState();
    state.setIsPlayingAndRequestBeatAtTime(playing, micros(hostMicros), beat, quantum);
    link->link->commitAppSessionState(state);
}

int64_t MCLinkClockMicros(MCLinkRef *link) {
    return count(link->link->clock().micros());
}

void MCLinkSetPeerCountCallback(MCLinkRef *link, void *context, MCLinkPeerCountCallback cb) {
    std::lock_guard<std::mutex> lock(link->callbackMutex);
    link->peerCtx = context;
    link->peerCb = cb;
}

void MCLinkSetTempoCallback(MCLinkRef *link, void *context, MCLinkTempoCallback cb) {
    std::lock_guard<std::mutex> lock(link->callbackMutex);
    link->tempoCtx = context;
    link->tempoCb = cb;
}

void MCLinkSetStartStopCallback(MCLinkRef *link, void *context, MCLinkStartStopCallback cb) {
    std::lock_guard<std::mutex> lock(link->callbackMutex);
    link->startStopCtx = context;
    link->startStopCb = cb;
}

bool MCLinkIsRealImplementation(void) {
    return true;
}

} // extern "C"
