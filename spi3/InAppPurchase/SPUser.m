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
//  SPUser.m
//  VoipPhone
//
//  Created by Ethan Arutunian on 12/31/14.
//
//

#import "SPUser.h"
#import "NSDictionaryExtras.h"
#import "NSDate+SCDate.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "RavenClient.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation SPUser

- (SPUser *)initWithDict:(NSDictionary *)dict {
/*
{
    "display_name": "Radagast the Brown",
    "uuid": "uvv9h7fbldqpfp82ed33dqv4lh",
    "display_alias": "radagast",
    "display_tn": "+16135558287",
    "avatar_url": "https://static.silentcircle.com/avatar/NQXmoRi4NrW9jxTasfyLQf/404/",
     devices =     {
      1234123412341234 =         {
       prekeys = 92;
      };
    };
    "subscription": {
        "expires": "1900-01-01T00:00:00Z",
        "autorenew": true,
        "model": "plan", # Can be "plan" or "credit"
        "state": "free",  # Can be "free", "expired", or "paying".
        "balance": {
            "amount": "7.8278",
            "unit": "USD"
        },
        "usage_details": {
            "minutes_left": 33,  # OCA minutes left in the month.
            "base_minutes": 100,  # The amount of minutes the user has purchased.
            "current_modifier": 0,  # A temporary amount of minutes added to base_minutes for this month.
            "spending": {  # This will show up for users with credit plans, instead of the above three keys.
                "current_month": {
                    "total": { 
                        "amount": "8.0123", 
                        "unit": "USD" 
                    }
                }
            }
        }
    },
    "permissions": {
        "maximum_burn_sec": 7776000,
        "outbound_calling_pstn": true,
        "outbound_calling": true,
        "create_conference": true,
        "initiate_video": true,
        "send_attachment": true,
    },
    "data_retention": {
        "for_org_name": "Subman",
        "retained_data": {
            "attachment_plaintext": false,
            "call_metadata": true,
            "call_plaintext": false,
            "message_metadata": true,
            "message_plaintext": false
        }
    },
}
*/
//   NSLog(@"dict=%@",dict);
	if ( (self =  [super init]) != nil) {
        self.uuid = [dict safeStringForKey:@"uuid"];
		self.avatarURL = [dict safeStringForKey:@"avatar_url"];
		self.displayName = [dict safeStringForKey:@"display_name"];
        self.displayAlias = [dict safeStringForKey:@"display_alias"];
        self.displayTN = [dict safeStringForKey:@"display_tn"];
        self.displayPlan = [dict safeStringForKey:@"display_plan"];
        self.displayOrganization = [dict safeStringForKey:@"display_organization"];
        self.devicesCnt = 0;

        NSDictionary *devicesDict = (NSDictionary*)[dict objectForKey:@"devices"];
        if(devicesDict){
            self.devicesCnt = (int)[[devicesDict allKeys] count];
            
            NSString *dev_id = [Switchboard getCurrentDeviceId];
            NSDictionary *dev = (NSDictionary*)[devicesDict objectForKey:dev_id];
            if(dev){
                self.prekeyCnt = [dev safeIntForKey:@"prekeys"];
            }
            else{
                DDLogWarn(@"%s self.prekeyCnt==0, no dev",__PRETTY_FUNCTION__);
            }
        }
        
        NSDictionary *subDict = [dict objectForKey:@"subscription"];
		if (subDict != nil) {
			NSString *expireS = [subDict safeStringForKey:@"expires"];
			NSDate *expireDate = [NSDate dateFromRfc3339String:expireS];

			// WEB-1078 : the server actually expires people the next day
			self.subscriptionExpireDate = [expireDate dateByAddingTimeInterval:(60 * 60 * 24)];
			self.subscriptionAutoRenews = [subDict safeBoolForKey:@"autorenew"];
            
            self.model = [subDict safeStringForKey:@"model"];
            
            if([self.model isEqualToString:@"plan"])
            {
                NSDictionary *usageDetailsDict = [subDict objectForKey:@"usage_details"];
                
                self.minutesLeft = [usageDetailsDict safeIntForKey:@"minutes_left"];
                self.totalMinutes = [usageDetailsDict safeIntForKey:@"base_minutes"] + [usageDetailsDict safeIntForKey:@"current_modifier"];
            }
            else // model == credit
            {
                NSDictionary *balanceDict = [subDict objectForKey:@"balance"];
                
                self.remainingCredit = [balanceDict safeDoubleForKey:@"amount"];
                self.creditCurrency = [balanceDict safeStringForKey:@"unit"];
            }
            
		} else {
			self.subscriptionExpireDate = nil;
			self.subscriptionAutoRenews = NO;
//            self.remainingCreditCents = 0;
            self.remainingCredit = 0;
            self.creditCurrency = nil;
		}
        
        NSDictionary *p = [dict objectForKey:@"permissions"];
        self.permissions = @{
             @(UserPermission_CanReceiveVoicemail): @([p safeBoolForKey:@"can_receive_voicemail"])
             ,@(UserPermission_CanSendMedia): @([p safeBoolForKey:@"can_send_media"])
             ,@(UserPermission_CreateConference): @([p safeBoolForKey:@"create_conference"])
             ,@(UserPermission_InboundCalling): @([p safeBoolForKey:@"inbound_calling"])
             ,@(UserPermission_InboundMessaging): @([p safeBoolForKey:@"inbound_messaging"])
             ,@(UserPermission_InitiateVideo): @([p safeBoolForKey:@"initiate_video"])
             ,@(UserPermission_OutboundCalling): @([p safeBoolForKey:@"outbound_calling"])
             ,@(UserPermission_OutboundPSTNCalling): @([p safeBoolForKey:@"outbound_calling_pstn"])
             ,@(UserPermission_OutboundMessaging): @([p safeBoolForKey:@"outbound_messaging"])
             ,@(UserPermission_SendAttachment): @([p safeBoolForKey:@"send_attachment"])
             };
        self.maximumBurnSecs = [p safeNumberForKey:@"maximum_burn_sec"];

#if HAS_DATA_RETENTION
        self.drEnabled = NO;
        self.drTypeCode = 0;
        self.drOrganization = nil;

        NSDictionary *drDict = [dict objectForKey:@"data_retention"];
        if (drDict) {
            self.drOrganization = [drDict safeStringForKey:@"for_org_name"];
            NSDictionary *retainedDR = [drDict objectForKey:@"retained_data"];
            self.drTypeCode = [SPUser DRTypeCodeFromDict:retainedDR];
            self.drEnabled = (self.drTypeCode > 0);
            if (self.drEnabled)
                NSLog(@"DR enabled with code = %d", self.drTypeCode);
            
            self.drBlockCode = 0;
            NSDictionary *drBlockDict = [drDict objectForKey:@"block_retention_of"];
            if (drBlockDict)
                self.drBlockCode = [SPUser DRBlockCodeFromDict:drBlockDict];
        }
#endif // HAS_DATA_RETENTION
	}

	return self;
}

/* EA: I thought I was going to need this but didn't end up using it:
- (NSDictionary *)toDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:12];
    if (self.userID)
        [dict setObject:self.userID forKey:@"userID"];
    if (self.uuid)
        [dict setObject:self.uuid forKey:@"uuid"];
    if (self.avatarURL)
        [dict setObject:self.avatarURL forKey:@"avatar_url"];
    if (self.displayName)
        [dict setObject:self.displayName forKey:@"display_name"];
    if (self.displayAlias)
        [dict setObject:self.displayAlias forKey:@"display_alias"];
    if (self.displayTN)
        [dict setObject:self.displayTN forKey:@"display_tn"];
    if (self.displayPlan)
        [dict setObject:self.displayPlan forKey:@"display_plan"];
    if (self.displayOrganization)
        [dict setObject:self.displayOrganization forKey:@"display_organization"];

    // NOTE: no way to get all devices here, only current one
    NSString *dev_id = [Switchboard getCurrentDeviceId];
    NSDictionary *devDict = @{@"prekeys": [NSNumber numberWithInt:self.prekeyCnt]};
    NSDictionary *devicesDict = @{dev_id: devDict};
    [dict setObject:devicesDict forKey:@"devices"];
          
    [dict setObject:@{
          @"can_receive_voicemail":[self hasPermission:UserPermission_CanReceiveVoicemail] ? @YES : @NO
          ,@"can_send_media":[self hasPermission:UserPermission_CanSendMedia] ? @YES : @NO
          ,@"create_conference":[self hasPermission:UserPermission_CreateConference] ? @YES : @NO
          ,@"inbound_calling":[self hasPermission:UserPermission_InboundCalling] ? @YES : @NO
          ,@"inbound_messaging":[self hasPermission:UserPermission_InboundMessaging] ? @YES : @NO
          ,@"initiate_video":[self hasPermission:UserPermission_InitiateVideo] ? @YES : @NO
          ,@"outbound_calling":[self hasPermission:UserPermission_OutboundCalling] ? @YES : @NO
          ,@"outbound_calling_pstn":[self hasPermission:UserPermission_OutboundPSTNCalling] ? @YES : @NO
          ,@"outbound_messaging":[self hasPermission:UserPermission_OutboundMessaging] ? @YES : @NO
          ,@"send_attachment":[self hasPermission:UserPermission_SendAttachment] ? @YES : @NO
          } forKey:@"permissions"];

    [dict setObject:self.maximumBurnSecs forKey:@"maximum_burn_sec"];
#if HAS_DATA_RETENTION
          // NYI
#endif // HAS_DATA_RETENTION

    if (self.subscriptionExpireDate) {
        NSDate *expireDate = [self.subscriptionExpireDate dateByAddingTimeInterval:(-60 * 60 * 24)];
        NSMutableDictionary *subDict = [NSMutableDictionary dictionaryWithDictionary:
                                        @{@"expires": [expireDate rfc3339String]
                                          ,@"autorenew": self.subscriptionAutoRenews ? @YES : @NO
                                          ,@"model": self.model}];

        if ([self.model isEqualToString:@"plan"]) {
            // NOTE: here we cannot support "base_minutes" so we save "total_minutes"
            [subDict setObject:@{@"minutes_left": [NSNumber numberWithInt:self.minutesLeft]
                                ,@"total_minutes": [NSNumber numberWithInt:self.totalMinutes]} forKey:@"usage_details"];
        } else
            [subDict setObject:@{@"amount": [NSNumber numberWithDouble:self.remainingCredit]
                                 ,@"unit": self.creditCurrency} forKey:@"balance"];
        [dict setObject:subDict forKey:@"subscription"];
    }
    return dict;
}
*/

#if HAS_DATA_RETENTION
+ (uint32_t)DRTypeCodeFromDict:(NSDictionary *)dict {
    if ([dict count] == 0)
        return kDRType_None;

    uint32_t code = 0;
    for (NSString *drTypeKey in [dict allKeys]) {
        BOOL isEnabled = [dict safeBoolForKey:drTypeKey];
        if ([@"attachment_plaintext" isEqualToString:drTypeKey])
            code = (isEnabled) ? (code | kDRType_Attachment_PlainText) : (code & ~kDRType_Attachment_PlainText);
        else if ([@"call_metadata" isEqualToString:drTypeKey])
            code = (isEnabled) ? (code | kDRType_Call_Metadata) : (code & ~kDRType_Call_Metadata);
        else if ([@"call_plaintext" isEqualToString:drTypeKey])
            code = (isEnabled) ? (code | kDRType_Call_PlainText) : (code & ~kDRType_Call_PlainText);
        else if ([@"message_metadata" isEqualToString:drTypeKey])
            code = (isEnabled) ? (code | kDRType_Message_Metadata) : (code & ~kDRType_Message_Metadata);
        else if ([@"message_plaintext" isEqualToString:drTypeKey])
            code = (isEnabled) ? (code | kDRType_Message_PlainText) : (code & ~kDRType_Message_PlainText);
    }
    return code;
}

+ (uint32_t)DRBlockCodeFromDict:(NSDictionary *)dict {
    if ([dict count] == 0)
        return kDRBlock_None;
    
    uint32_t code = 0;
    if ([dict safeBoolForKey:@"remote_metadata"])
        code |= kDRBlock_RemoteMetadata;
    if ([dict safeBoolForKey:@"remote_data"])
        code |= kDRBlock_RemoteData;
    if ([dict safeBoolForKey:@"local_metadata"])
        code |= kDRBlock_LocalMetadata;
    if ([dict safeBoolForKey:@"local_data"])
        code |= kDRBlock_LocalData;
    return code;
}
#endif // HAS_DATA_RETENTION

- (BOOL)hasPermission:(UserPermission)permission {
//#warning EA TESTING - PUT THIS BACK IN
//return NO;
    return [self.permissions safeBoolForKey:@(permission)];
}

- (NSString *)localizedRemainingCredits {
//    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
//    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
//    [formatter setLocale:[NSLocale currentLocale]];
//    NSString *localizedMoneyString = [formatter stringFromNumber:@((double)_remainingCreditCents/100.0)];
//    [formatter release];
//    return localizedMoneyString;
    return [[NSString stringWithFormat:@"%1.2lf ", _remainingCredit] stringByAppendingString:_creditCurrency];
}

@end

