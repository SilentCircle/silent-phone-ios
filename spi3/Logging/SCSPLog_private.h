//
//  SCSPLog_private.h
//  SPi3
//
//  Created by Eric Turner on 2/23/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#ifndef SCSPLog_private_h
#define SCSPLog_private_h

#pragma mark - TIVI
//----------------------------------------------------------------------
// TIVI LOGGING CONTEXTS
#define TV_CONTEXT 100  //generic

#define TV_Error(frmt, ...) LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_Info(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF,  DDLogFlagInfo,  TV_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define TV_EVENTS_CONTEXT 110
#define TV_EventsError(frmt, ...) LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_EVENTS_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_EventsInfo(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,   TV_EVENTS_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define TV_SIP_CONTEXT    120
#define TV_SIPError(frmt, ...)   LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_SIP_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_SIPInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,  TV_SIP_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define TV_ZRTP_CONTEXT   130
#define TV_ZRTPError(frmt, ...)  LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_ZRTP_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_ZRTPInfo(frmt, ...)   LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,  TV_ZRTP_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define TV_AUDIO_CONTEXT  140
#define TV_AudioError(frmt, ...) LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_AUDIO_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_AudioInfo(frmt, ...)  LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,  TV_AUDIO_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define TV_AUDIO_STATS_CONTEXT 150
#define TV_Audio_statsError(frmt, ...)   LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError, TV_AUDIO_STATS_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define TV_Audio_statsInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,  TV_AUDIO_STATS_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

enum TIVI_LOG_TYPE {
    tivi_log             = 100,
    tivi_log_events      = 110,
    tivi_log_sip         = 120,
    tivi_log_zrtp        = 130,
    tivi_log_audio       = 140,
    tivi_log_audio_stats = 150,
};
// Main C/C++ interface to CocoaLumberjack logging
void ios_log_tivi(int context, const char *tag, const char *buf);
//----------------------------------------------------------------------


#pragma mark - ZINA
//----------------------------------------------------------------------
// ZINA LOGGING CONTEXTS
#define ZINA_CONTEXT 200

#define ZINALogError(frmt, ...)   LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError,   ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define ZINALogWarn(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagWarning, ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define ZINALogInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,    ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define ZINALogDebug(frmt, ...)   LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagDebug,   ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define ZINALogVerbose(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define ZINALogEpic(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, ZINA_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

// ZINA logging interface to CocoaLumberjack logging
void set_zina_log_cb(void *pRet, void (*cb)(void *ret, const char *tag, const char *buf));
void ios_log_zina(void *ret, const char *tag, const char *buf);
//----------------------------------------------------------------------


#endif /* SCSPLog_private_h */
