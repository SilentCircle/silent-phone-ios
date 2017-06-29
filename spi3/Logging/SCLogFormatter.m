//
//  SCLogFormatter.m
//  SPi3
//
//  Created by Eric Turner on 2/24/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCLogFormatter.h"
#import "SCSPLog.h"
#import "SCSPLog_private.h"
#import "NSURL+SCUtilities.h"

@implementation SCLogFormatter
{
    NSUInteger _calendarUnitFlags;
}

- (instancetype)initUsingTimestamp {
    self = [super init];
    if (!self) { return nil; }
    
    useTimestamp = YES;
    _calendarUnitFlags = (NSCalendarUnitYear     |
                          NSCalendarUnitMonth    |
                          NSCalendarUnitDay      |
                          NSCalendarUnitHour     |
                          NSCalendarUnitMinute   |
                          NSCalendarUnitSecond);

    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *ctx = [self contextString:logMessage->_context];
    NSString *lvl = [self logLevelString:logMessage->_level];
    if (useTimestamp && logMessage->_timestamp) {
        NSString *ts = [self stringFromDate:logMessage->_timestamp];
        return [NSString stringWithFormat:@"%@%@%@%@", ts, ctx, lvl, logMessage->_message];
    }
    return [NSString stringWithFormat:@"%@%@%@", ctx, lvl, logMessage->_message];
}

- (NSString *)logLevelString:(NSInteger)lvl {
    NSString *str = @"<N/A>";
    switch (lvl) {
        case DDLogLevelOff     : str = @"<Off>";     break;
        case DDLogLevelError   : str = @"<Error>";   break;
        case DDLogLevelWarning : str = @"<Warning>"; break;    
        case DDLogLevelInfo    : str = @"<Info>";    break;
        case DDLogLevelDebug   : str = @"<Debug>";   break;
        case DDLogLevelVerbose : str = @"<Verbose>"; break;
        case DDLogLevelAll     : str = @"<All>";     break;
        default: break;
    }    
    return str;
}

- (NSString *)contextString:(NSInteger)ctx {
    NSString *str = @"";
    switch (ctx) {
        case AUDIO_LOG_CONTEXT          : str = @"[AUDIO]";         break;
        case CALLKIT_LOG_CONTEXT        : str = @"[CALLKIT]";       break;
        case HTTP_LOG_CONTEXT           : str = @"[HTTP]";          break;    
        case TV_CONTEXT                 : str = @"[TIVI]";          break;
        case TV_EVENTS_CONTEXT          : str = @"[TV_EVENT]";      break;
        case TV_SIP_CONTEXT             : str = @"[TV_SIP]";        break;
        case TV_ZRTP_CONTEXT            : str = @"[TV_ZRTP]";       break;
        case TV_AUDIO_CONTEXT           : str = @"[TV_AUDIO]";      break;
        case TV_AUDIO_STATS_CONTEXT     : str = @"[TV_AUDIO_STAT]"; break;    
        case ZINA_CONTEXT               : str = @"[ZINA]";          break;
        default                         : str = @"[SPi]";           break;
    }    
    return str;
}

- (NSString *)stringFromDate:(NSDate *)tstamp {
    if (!tstamp) return @"";
    
    // Calculate timestamp.
    // The technique below is faster than using NSDateFormatter.
    NSDateComponents *components = [[NSCalendar autoupdatingCurrentCalendar] components:_calendarUnitFlags fromDate:tstamp];
    
    NSTimeInterval epoch = [tstamp timeIntervalSinceReferenceDate];
    int milliseconds = (int)((epoch - floor(epoch)) * 1000);
    
    char ts[24] = "";
    snprintf(ts, 24, "%04ld-%02ld-%02ld %02ld:%02ld:%02ld:%03d", // yyyy-MM-dd HH:mm:ss:SSS
                   (long)components.year,
                   (long)components.month,
                   (long)components.day,
                   (long)components.hour,
                   (long)components.minute,
                   (long)components.second, milliseconds);

    return [NSString stringWithUTF8String:ts];
}

@end
