// AbletonLinkBridge — C ABI over Ableton Link's C++ API.
// Swift-importable; never leaks C++ templates. Opaque handle owns the
// underlying ableton::Link (once Phase 0 wires the real source).
//
// Time domain: all *Micros arguments/returns are Link's clock micros
// (MCLinkClockMicros). NEVER pass Date/DispatchTime values here — timing
// code converts mach host-time to Link micros through one conversion layer.
//
// GPLv2-or-later. Synclock.

#ifndef SYNCLOCK_ABLETON_LINK_BRIDGE_H
#define SYNCLOCK_ABLETON_LINK_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MCLinkRef MCLinkRef;

typedef void (*MCLinkPeerCountCallback)(void *context, uint32_t peers);
typedef void (*MCLinkTempoCallback)(void *context, double bpm);
typedef void (*MCLinkStartStopCallback)(void *context, bool isPlaying);

// Lifecycle.
MCLinkRef *MCLinkCreate(double initialBPM);
void MCLinkDestroy(MCLinkRef *link);

// Session participation.
void MCLinkSetEnabled(MCLinkRef *link, bool enabled);
bool MCLinkIsEnabled(MCLinkRef *link);
void MCLinkSetStartStopSyncEnabled(MCLinkRef *link, bool enabled);
bool MCLinkIsStartStopSyncEnabled(MCLinkRef *link);
uint32_t MCLinkPeerCount(MCLinkRef *link);

// Tempo.
double MCLinkTempo(MCLinkRef *link);
void MCLinkSetTempo(MCLinkRef *link, double bpm, int64_t hostMicros);

// Beat / phase mapping (quantum = beats per bar/cycle, e.g. 4).
double MCLinkBeatAtTime(MCLinkRef *link, int64_t hostMicros, double quantum);
double MCLinkPhaseAtTime(MCLinkRef *link, int64_t hostMicros, double quantum);
int64_t MCLinkTimeAtBeat(MCLinkRef *link, double beat, double quantum);
void MCLinkRequestBeatAtTime(MCLinkRef *link, double beat, int64_t hostMicros, double quantum);

// Transport.
bool MCLinkIsPlaying(MCLinkRef *link);
int64_t MCLinkTimeForIsPlaying(MCLinkRef *link);
void MCLinkSetIsPlaying(MCLinkRef *link, bool playing, int64_t hostMicros);
void MCLinkSetIsPlayingAndRequestBeatAtTime(MCLinkRef *link, bool playing,
                                            int64_t hostMicros, double beat,
                                            double quantum);

// Canonical Link clock (microseconds).
int64_t MCLinkClockMicros(MCLinkRef *link);

// Callbacks (delivered on Link's thread; the Swift side must hop to its own
// core queue, never touch AppKit directly).
void MCLinkSetPeerCountCallback(MCLinkRef *link, void *context, MCLinkPeerCountCallback cb);
void MCLinkSetTempoCallback(MCLinkRef *link, void *context, MCLinkTempoCallback cb);
void MCLinkSetStartStopCallback(MCLinkRef *link, void *context, MCLinkStartStopCallback cb);

// True once the real Ableton Link source is compiled in (Phase 0). While this
// returns false the bridge is the local STUB: it tracks tempo/transport/playing
// state in-process but does not join any Link network (peer count stays 0).
bool MCLinkIsRealImplementation(void);

#ifdef __cplusplus
}
#endif

#endif // SYNCLOCK_ABLETON_LINK_BRIDGE_H
