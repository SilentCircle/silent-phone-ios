//
//  SCSPLog_private.c
//  SPi3
//
//  Created by Eric Turner on 2/23/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//


#import "SCSPLog_private.h"
#import "SCSPLog.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

#ifdef DEBUG
void ios_log_tivi(int context, const char *tag, const char *buf) {
    switch (context) {
        case tivi_log_events:
            TV_EventsInfo(@"-(%s) %s", tag, buf);
            break;
        case tivi_log_sip:
            TV_SIPInfo(@"-(%s) %s", tag, buf);
            break;
        case tivi_log_zrtp:
            TV_ZRTPInfo(@"-(%s) %s", tag, buf);
            break;
        case tivi_log_audio:
            TV_AudioInfo(@"-(%s) %s", tag, buf);
            break;
        case tivi_log_audio_stats:
            TV_Audio_statsInfo(@"-(%s) %s", tag, buf);
            break;            
        default:
            TV_Info(@"-(%s) %s", tag, buf);
            break;
    }
}

//see main.mm for original (commented) JN zina log implementation
void ios_log_zina(void *ret, const char *tag, const char *buf) {

    switch (ddLogLevel) {
        case DDLogLevelError:
            ZINALogError(@"%s", buf);
            break;
        case DDLogLevelWarning:
            ZINALogWarn(@"%s", buf);
            break;
        case DDLogLevelInfo:
            ZINALogInfo(@"%s", buf);
            break;
        case DDLogLevelDebug:
            ZINALogDebug(@"%s", buf);
            break;
        case DDLogLevelVerbose:
            ZINALogVerbose(@"%s", buf);
            break;            
        case DDLogLevelAll:
            ZINALogEpic(@"%s", buf);
            break;                        
        case DDLogLevelOff:    
        default:
            break;
    }
}
#else
void ios_log_tivi(int context, const char *tag, const char *buf) { }
void ios_log_zina(void *ret, const char *tag, const char *buf)   { }
#endif
