/*
Copyright (C) 2012-2017, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>
#import "NSDate+SCDate.h"

#define D_MINUTE	60
#define D_HOUR		3600
#define D_DAY		86400
#define D_WEEK		604800
#define D_YEAR		31556926

#define DATE_COMPONENTS (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekOfYear |  NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitWeekday | NSCalendarUnitWeekdayOrdinal)
#define CURRENT_CALENDAR [NSCalendar currentCalendar]

//#import "SCCalendar.h"
//#import "SCDateFormatter.h"


@implementation NSDate (whenString)
/*
- (NSDate *)dateWithZeroTime
{
	// Contrary to popular belief, [NSCalendar currentCalendar] is NOT a singleton.
	// A new instance is created each time you invoke the method.
	// Use SCCalendar for extra fast access to a NSCalendar instance.
	NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
	
	NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday;
	NSDateComponents *comps = [calendar components:units fromDate:self];
	[comps setHour:0];
	[comps setMinute:0];
	[comps setSecond:0];
	
	return [calendar dateFromComponents:comps];
}

- (NSString *)whenString
{
	NSDate *selfZero = [self dateWithZeroTime];
    NSDate *todayZero = [[NSDate date] dateWithZeroTime];
    NSTimeInterval interval = [todayZero timeIntervalSinceDate:selfZero];
    NSTimeInterval dayDiff = interval/(60*60*24);
   
	// IMPORTANT:
	// This method is used often.
	// Creating a new dateFormatter each time is very expensive.
	// Instead we use the SCDateFormatter class, which caches these things for us automatically (and is thread-safe).
    NSDateFormatter *formatter;
    
	if (dayDiff == 0) // today: show time only
	{
		formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterNoStyle
		                                              timeStyle:NSDateFormatterShortStyle];
    }
	else if (fabs(dayDiff) == 1) // tomorrow or yesterday: use relative date formatting
	{
		formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
		                                              timeStyle:NSDateFormatterNoStyle
		                             doesRelativeDateFormatting:YES];
    }
	else if (fabs(dayDiff) < 7) // within next/last week: show weekday
	{
		formatter = [SCDateFormatter dateFormatterWithLocalizedFormat:@"EEEE"];
	}
	else if (fabs(dayDiff) > (365 * 4)) // distant future or past: show year
	{
		formatter = [SCDateFormatter dateFormatterWithLocalizedFormat:@"y"];
	}
	else // show date
	{
		formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
		                                              timeStyle:NSDateFormatterNoStyle];
	}
    
    return [formatter stringFromDate:self];
}
*/

static NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.

- (NSString *)rfc3339String
{
    // Quinn "The Eskimo" pointed me to:
    // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
    // The contained advice recommends all internet time formatting to use US POSIX standards.
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
	
    NSTimeZone *gmtTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
	
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = enUSPOSIXLocale;
    formatter.timeZone = gmtTimeZone;
    formatter.dateFormat = kZuluTimeFormat;
    formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	return [formatter stringFromDate:self];
}

+ (NSDate *)dateFromRfc3339String:(NSString *)dateString
{
	if (dateString == nil) return nil;
    
    // Quinn "The Eskimo" pointed me to:
    // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
    // The contained advice recommends all internet time formatting to use US POSIX standards.
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
    
	NSTimeZone *gmtTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
	
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = enUSPOSIXLocale;
    formatter.timeZone = gmtTimeZone;
    formatter.dateFormat = kZuluTimeFormat;
    formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	return [formatter dateFromString:dateString];
}
/*
+ (NSDate *)dateFromSh:(NSString *)dateString
{
	if (dateString == nil) return nil;
	
	// Note: dateFormatters are NOT thread-safe
	
	NSString *dateFormat = @"EEE MMM dd HH:mm:ss z yyyy";
	NSLocale *enUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	
	// Use cached dateFormatter in thread dictionary
    NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithLocalizedFormat:dateFormat locale:enUS];
	
	return [formatter dateFromString:dateString];
}
*/
+ (NSDate *)dateFromEXIF:(NSString *)dateString
{
	if (dateString == nil) return nil;
	
	// Note: dateFormatters are NOT thread-safe
	
	NSString *dateFormat = @"yyyy:MM:dd HH:mm:ss";
	
	// Use cached dateFormatter in thread dictionary
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = dateFormat;
    formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    return [formatter dateFromString:dateString];
}

- (NSString *)ExifString
{
	// Note: dateFormatters are NOT thread-safe
	
	NSString *dateFormat = @"yyyy:MM:dd HH:mm:ss";
	NSTimeZone *utcTimeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    
	// Use cached dateFormatter in thread dictionary
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = dateFormat;
    formatter.timeZone = utcTimeZone;
    formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	
	return [formatter stringFromDate:self];
}

#pragma mark Adjusting Dates

- (NSDate *) dateByAddingDays: (NSInteger) dDays
{
    NSTimeInterval aTimeInterval = [self timeIntervalSinceReferenceDate] + D_DAY * dDays;
    NSDate *newDate = [NSDate dateWithTimeIntervalSinceReferenceDate:aTimeInterval];
    return newDate;
}

- (NSDate *) dateBySubtractingDays: (NSInteger) dDays
{
    return [self dateByAddingDays: (dDays * -1)];
}

#pragma mark Comparing Dates

+ (NSDate *) dateWithDaysBeforeNow: (NSInteger) days
{
    // Thanks, Jim Morrison
    return [[NSDate date] dateBySubtractingDays:days];
}

+ (NSDate *) dateYesterday
{
    return [NSDate dateWithDaysBeforeNow:1];
}

- (BOOL) isEqualToDateIgnoringTime: (NSDate *) aDate
{
    NSDateComponents *components1 = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
    NSDateComponents *components2 = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:aDate];
    return ((components1.year == components2.year) &&
            (components1.month == components2.month) &&
            (components1.day == components2.day));
}

- (BOOL) isToday
{
    return [self isEqualToDateIgnoringTime:[NSDate date]];
}

- (BOOL) isYesterday
{
    return [self isEqualToDateIgnoringTime:[NSDate dateYesterday]];
}

/*
- (BOOL)isBefore:(NSDate *)date
{
	return ([self compare:date] == NSOrderedAscending);
}

- (BOOL)isAfter:(NSDate *)date
{
	return ([self compare:date] == NSOrderedDescending);
}

- (BOOL)isBeforeOrEqual:(NSDate *)date
{
	NSComparisonResult result = [self compare:date];
	return (result == NSOrderedAscending ||
	        result == NSOrderedSame);
}

- (BOOL)isAfterOrEqual:(NSDate *)date
{
	NSComparisonResult result = [self compare:date];
	return (result == NSOrderedDescending ||
	        result == NSOrderedSame);
}

- (NSDate *)beginningOfDay
{
	// Contrary to popular belief, [NSCalendar currentCalendar] is NOT a singleton.
	// A new instance is created each time you invoke the method.
	// Use SCCalendar for extra fast access to a NSCalendar instance.
    NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
	
	NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents *components = [calendar components:units fromDate:self];
    
    return [calendar dateFromComponents:components];
}

- (NSDate *)endOfDay
{
	// Contrary to popular belief, [NSCalendar currentCalendar] is NOT a singleton.
	// A new instance is created each time you invoke the method.
	// Use SCCalendar for extra fast access to a NSCalendar instance.
	NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
    
    NSDateComponents *components = [NSDateComponents new];
    components.day = 1;
    
    NSDate *date = [calendar dateByAddingComponents:components
                                             toDate:self.beginningOfDay
                                            options:0];
    
    date = [date dateByAddingTimeInterval:-1];
    
    return date;
}

NSDate* SCEarliestDate2(NSDate *date1, NSDate *date2)
{
	if (date1 && date2) {
		return [date1 isBefore:date2] ? date1 : date2;
	}
	else {
		return date1 ? date1 : date2;
	}
}

NSDate* SCEarliestDate3(NSDate *date1, NSDate *date2, NSDate *date3)
{
	return SCEarliestDate2(SCEarliestDate2(date1, date2), date3);
}

BOOL SCEqualDates(NSDate *date1, NSDate *date2)
{
	if (date1)
	{
		if (date2)
		{
			// date1 && date2
			return [date1 isEqualToDate:date2];
		}
		else
		{
			// date1 && !date2
			return NO;
		}
	}
	else if (date2)
	{
		// !date1 && date2
		return NO;
	}
	else
	{
		// !date1 && !date2
		return YES;
	}
}
*/
@end
