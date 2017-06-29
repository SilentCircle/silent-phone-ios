/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

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
//
//  NSDictionaryExtras.m

#import "NSDictionaryExtras.h"
//#import "NSStringExtras.h"

@implementation NSDictionary (AZExtras)

- (BOOL)contains:(NSObject *)key
{
	return ([self objectForKey:key] != nil);
}

- (NSString *)safeStringForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return nil;
	if (![value isKindOfClass:[NSString class]])
		return nil;	
	return value;
}

- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format
{
	return [self safeDateForKey:key format:format timezone:@"PST"]; // default server timezone
}

- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format timezone:(NSString *)timezone
{
	NSDate *resultDate = nil;
	NSString *dateS = [self safeStringForKey:key];
	if ([dateS length] > 0) {	
		// convert date out of server time
		NSTimeZone *timeZoneServer = [NSTimeZone timeZoneWithAbbreviation:timezone];
		NSDateFormatter *df = [[NSDateFormatter alloc] init];
		[df setTimeZone:timeZoneServer];
		[df setDateFormat:format];
        df.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
		resultDate = [df dateFromString:dateS]; // [[df dateFromString:dateS] retain];
		//[df release];
	}
	return resultDate;
}

- (NSNumber *)safeNumberForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return nil;
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if (![value isKindOfClass:[NSString class]])
		return nil;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	return n;
}
- (NSNumber *)safeNumberNoNILForKey:(NSString *)key
{
	id value = [self safeNumberForKey:key];
	if (!value)
		value = [NSNumber numberWithInt:0];
	return value;
}

- (BOOL)safeBoolForKey:(NSObject *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return NO;
	if ([value isKindOfClass:[NSNumber class]])
		return ([value intValue] != 0);
	if (![value isKindOfClass:[NSString class]])
		return NO;

	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return ([n intValue] != 0);
}

- (int)safeIntForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value intValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return [n intValue];
}

- (double)safeDoubleForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value doubleValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return [n doubleValue];
}

- (unsigned long)safeUnsignedLongForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value unsignedLongValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	return [n unsignedLongValue];
}

@end
