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
#import <AudioToolbox/AudioServices.h>
#import <Intents/Intents.h>
#include "interfaceApp/AppInterfaceImpl.h"
#include "storage/NameLookup.h"

#import "ChatUtilities.h"
#import "ChatObject.h"
#import "CTNumberHelper.h"
#import "DBManager.h"
#import "DBManager+MessageReceiving.h"
#import "SCSFeatures.h"
#import "LocalAlertView.h"
#import "MWSPinLockScreenVC.h"
#import "RecentObject.h"
#import "SCloudConstants.h"
#import "SCFileManager.h"
#import "SCPCall.h"
#import "SCPNotificationKeys.h"
#import "SCSContactsManager.h"
#import "SCSContainerController.h"
#import "UserService.h"
#import "SCPSettingsManager.h"
#import "SCSAvatarManager.h"
#import "SCSConstants.h"
//Categories
#import "NSString+URLEncoding.h"
#import "NSDictionaryExtras.h"
#import "SCPCallbackInterface.h"
#import "UIImage+ApplicationImages.h"

#define kReceivedBackgroundRectangle [UIImage imageNamed:@"ReceivedRectangle.png"]
#define kSentBackgroundRectangle [UIImage imageNamed:@"SentRectangle.png"]

#define kCallBubbleBackground [UIImage imageNamed:@"CallBubbleBackground.png"]
#define kMissedCallBackground [UIImage imageNamed:@"MissedCallBubbleBackground.png"]

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

using namespace std;

@implementation ChatUtilities

+(ChatUtilities *)utilitiesInstance
{
    static dispatch_once_t once;
    static ChatUtilities *utilitiesInstance;
    dispatch_once(&once, ^{
        utilitiesInstance = [[ChatUtilities alloc] init];
        utilitiesInstance.isChatThreadVisible = NO;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        utilitiesInstance.screenHeight = screenRect.size.height;
        utilitiesInstance.screenWidth = screenRect.size.width;
        
        // app has been launched in landscape mode, so switch values
        if (screenRect.size.width > screenRect.size.height) {
            utilitiesInstance.screenHeight = screenRect.size.width;
            utilitiesInstance.screenWidth = screenRect.size.height;
        }
      //  utilitiesInstance.chatHistory = [[NSMutableDictionary alloc] init];
       // utilitiesInstance.recents = [[NSMutableDictionary alloc] init];

        
        utilitiesInstance.kNavigationBarColor = [UIColor colorWithRed:54/255.0f green:55/255.0f blue:59/255.0f alpha:1.0f];
        utilitiesInstance.kChatViewBackgroundColor = [UIColor colorWithRed:54/255.0f green:55/255.0f blue:59/255.0f alpha:1.0f];
        utilitiesInstance.kStatusBarColor = utilitiesInstance.kNavigationBarColor;
        utilitiesInstance.kAlertPointBackgroundColor = [UIColor colorWithRed:239/225.0 green:39/225.0 blue:27/225.0 alpha:1.0f];
        utilitiesInstance.kStatusBarHeight = 20;
       // utilitiesInstance.receivedMessageBadges = [[NSMutableDictionary alloc] init];
        utilitiesInstance.forwardedMessageData = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        utilitiesInstance.kDefaultBurnTime = 60 * 60 *24 *3;
        
        utilitiesInstance.avatarDownloadQueue = [[NSOperationQueue alloc] init];
        
        utilitiesInstance.kMessageLoadingCount = 10;
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"lockKey"])
            utilitiesInstance.isLockEnabled = YES;
        else
            utilitiesInstance.isLockEnabled = NO;
        
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"savedMessageTexts"])
        {
            utilitiesInstance.savedMessageTexts = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedMessageTexts"] mutableCopy];
        } else
        {
            utilitiesInstance.savedMessageTexts = [[NSMutableDictionary alloc] init];
        }
        
        /*if([[NSUserDefaults standardUserDefaults] objectForKey:@"unreadMessages"])
        {
            utilitiesInstance.unreadMessages = [[[NSUserDefaults standardUserDefaults] objectForKey:@"unreadMessages"] mutableCopy];
        } else
        {*/
            utilitiesInstance.unreadMessages = [[NSMutableDictionary alloc] init];
       // }
        
        
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"savedMapType"])
        {
            utilitiesInstance.savedMapType = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedMapType"] intValue];
        } else
        {
            utilitiesInstance.savedMapType = 0;
        }
        
        //savedShowLocationState
        
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"savedShowLocationState"])
        {
            utilitiesInstance.savedShowLocationState = [[[NSUserDefaults standardUserDefaults] objectForKey:@"savedShowLocationState"] intValue];
        } else
        {
            utilitiesInstance.savedShowLocationState = 0;
        }
        
        if([[NSUserDefaults standardUserDefaults] objectForKey:@"stackedBurns"])
        {
           //TODO cleanup [ChatUtilities utilitiesInstance].stackedBurns if they are too old
            utilitiesInstance.stackedBurns = [[[NSUserDefaults standardUserDefaults] objectForKey:@"stackedBurns"] mutableCopy];
        } else
        {
            utilitiesInstance.stackedBurns = [[NSMutableArray alloc] init];
        }
        
        
        utilitiesInstance.stackedOfflineBurns = [[NSMutableDictionary alloc] init];
        utilitiesInstance.stackedOfflineReads = [[NSMutableDictionary alloc] init];
        
        utilitiesInstance.savedUnsentNewConversationMessages = [[NSMutableDictionary alloc] init];
        
        utilitiesInstance.gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        utilitiesInstance.dateFormatter = [[NSDateFormatter alloc] init];
        [utilitiesInstance.dateFormatter setDateFormat:@"HH:mm"];
        [utilitiesInstance.dateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [utilitiesInstance.dateFormatter setDoesRelativeDateFormatting:NO];
       // [ChatUtilitiesInstance.dateFormatter setDateStyle:kCFDateFormatterShortStyle];
        [utilitiesInstance.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [utilitiesInstance.dateFormatter setCalendar:utilitiesInstance.gregorianCalendar];
        
        utilitiesInstance.chatListDateFormatter = [NSDateFormatter new];
        [utilitiesInstance.chatListDateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [utilitiesInstance.chatListDateFormatter setDoesRelativeDateFormatting:YES];
        [utilitiesInstance.chatListDateFormatter setDateStyle:NSDateFormatterShortStyle];
        [utilitiesInstance.chatListDateFormatter setCalendar:utilitiesInstance.gregorianCalendar];
        
        utilitiesInstance.chatViewHeaderdateFormatter = [[NSDateFormatter alloc] init];
        [utilitiesInstance.chatViewHeaderdateFormatter setDateFormat:@"EEEE"];
        [utilitiesInstance.chatViewHeaderdateFormatter setTimeStyle:NSDateFormatterNoStyle];
        [utilitiesInstance.chatViewHeaderdateFormatter setDoesRelativeDateFormatting:YES];
         [utilitiesInstance.chatViewHeaderdateFormatter setDateStyle:NSDateFormatterLongStyle];
        [utilitiesInstance.chatViewHeaderdateFormatter setCalendar:utilitiesInstance.gregorianCalendar];
        //[ChatUtilitiesInstance.chatViewHeaderdateFormatter setTimeStyle:kCFDateFormatterShortStyle];
       
        
        //chatViewHeaderdateFormatter
       
        utilitiesInstance.dateFormatterISO = [[NSDateFormatter alloc] init];
        [utilitiesInstance.dateFormatterISO setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
        [utilitiesInstance.dateFormatterISO setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [utilitiesInstance.dateFormatterISO setCalendar:utilitiesInstance.gregorianCalendar];
        

        
        [[NSNotificationCenter defaultCenter] addObserver:utilitiesInstance
                                                 selector:@selector(updateAppBadge:)
                                                     name:kSCSResetAppBadgeNumberNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:utilitiesInstance
                                                 selector:@selector(callsChanged:)
                                                     name:@"SCCallsChangedNotification"
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:utilitiesInstance
                                                 selector:@selector(outgoingCall:)
                                                     name:kSCPOutgoingCallNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:utilitiesInstance selector:@selector(fontDidChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
        
        
        utilitiesInstance.receivedMessageBackground = [kReceivedBackgroundRectangle resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5) resizingMode:UIImageResizingModeStretch];
        utilitiesInstance.sentMessageBackground = [kSentBackgroundRectangle resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5) resizingMode:UIImageResizingModeStretch];
        
        utilitiesInstance.callBubbleBackground = [kCallBubbleBackground resizableImageWithCapInsets:UIEdgeInsetsMake(5, 20, 5, 5) resizingMode:UIImageResizingModeStretch];
        utilitiesInstance.missedCallBubbleBackground = [kMissedCallBackground resizableImageWithCapInsets:UIEdgeInsetsMake(5, 20, 5, 5) resizingMode:UIImageResizingModeStretch];
        
        utilitiesInstance.shouldOpenChatViewFromNotification = YES;
        
        
        utilitiesInstance.allBurnValues = [[NSMutableArray alloc] initWithObjects:
                                                              @"1",[NSString stringWithFormat:NSLocalizedString(@"%d Minute", nil), 1],
                                                              @"5", [NSString stringWithFormat:NSLocalizedString(@"%d Minutes", nil), 5],
                                                              @"10", [NSString stringWithFormat:NSLocalizedString(@"%d Minutes", nil), 10],
                                                              @"15", [NSString stringWithFormat:NSLocalizedString(@"%d Minutes", nil), 15],
                                                              @"30", [NSString stringWithFormat:NSLocalizedString(@"%d Minutes", nil), 30],
                                                              @"60", [NSString stringWithFormat:NSLocalizedString(@"%d Hour", nil), 1],
                                                              @"180", [NSString stringWithFormat:NSLocalizedString(@"%d Hours", nil), 3],
                                                              @"360", [NSString stringWithFormat:NSLocalizedString(@"%d Hours", nil), 6],
                                                              @"720", [NSString stringWithFormat:NSLocalizedString(@"%d Hours", nil), 12],
                                                              @"1440", [NSString stringWithFormat:NSLocalizedString(@"%d Day", nil), 1],
                                                              @"2880", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 2],
                                                              @"4320", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 3],
                                                              @"5760", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 4],
                                                              @"7200", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 5],
                                                              @"10080", [NSString stringWithFormat:NSLocalizedString(@"%d Week", nil), 1],
                                                              @"20160", [NSString stringWithFormat:NSLocalizedString(@"%d Weeks", nil), 2],
                                                              @"40320", [NSString stringWithFormat:NSLocalizedString(@"%d Weeks", nil), 4],
                                                              @"43200", [NSString stringWithFormat:NSLocalizedString(@"%d Month", nil), 1],
                                                              @"64800", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 45],
                                                              @"129600", [NSString stringWithFormat:NSLocalizedString(@"%d Days", nil), 90],
                                                              nil];
    });
    
    return utilitiesInstance;
}


-(BOOL) existsUrlInText:(NSString *)text {
    
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    
    
    NSArray *matches = [linkDetector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    for (NSTextCheckingResult *match in matches)
    {
        if ([match resultType] == NSTextCheckingTypeLink)
        {
            return YES;
        }
    }
    return NO;
}

-(void)outgoingCall:(NSNotification*)notification
{
    SCPCall *callObject = (SCPCall *) [notification.userInfo objectForKey:kSCPCallDictionaryKey];
    if (!callObject)
        return;
    NSString *contactName = nil;
    if (callObject.bufPeer) {
        contactName = callObject.bufPeer;
    } else
    {
        contactName = callObject.bufDialed;
    }
    [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
}

-(void)callsChanged:(NSNotification*)notification {
    
    NSNumber *callsNumber = [notification object];
    
    _callCnt = callsNumber.intValue;
}

-(void)updateAppBadge:(NSNotification*)notification {
    
    int chats = [[self getBadgeValueForChatTabBar] intValue];
    
    NSString *badgeNumberStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"badgeNumberForRecents"];
    int badgeNumber = 0;
    if(badgeNumberStr)
    {
        badgeNumber = [badgeNumberStr intValue];
    }
    
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    if(![keyWindow.rootViewController isKindOfClass:[SCSContainerController class]])
        return;
    
    int total = chats + badgeNumber;
    
    /* burger
    SCSContainerController *containerVC = (SCSContainerController *)[UIApplication sharedApplication].keyWindow.rootViewController;    
    [containerVC.rootViewController setConversationsBadge:[NSString stringWithFormat:@"%i",total]]; */
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = total;
}

#pragma mark domain name handling for username string
-(NSString *) removePeerInfo:(NSString*) fullString lowerCase:(BOOL) lowerCase
{
    NSString *contactName;
    NSArray *splitContactNameArr;
      if ([fullString rangeOfString:@"@sip.silentcircle.net" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        splitContactNameArr = [fullString componentsSeparatedByString:@"@"];
        contactName = splitContactNameArr[0];
    } else
    {
        contactName = fullString;
    }
    
    if ([contactName rangeOfString:@":" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        splitContactNameArr = [contactName componentsSeparatedByString:@":"];
        contactName = splitContactNameArr[1];//[self removePeerInfo:splitContactNameArr[1] lowerCase:NO];
    }
    
    //afte calling device username may contain ;xscdevid = ... after username
    if ([contactName rangeOfString:@";" options:NSCaseInsensitiveSearch].location != NSNotFound)
    {
        splitContactNameArr = [contactName componentsSeparatedByString:@";"];
        contactName = splitContactNameArr[0];//[self removePeerInfo:splitContactNameArr[1] lowerCase:NO];
    }
    
    if(lowerCase)
    {
        contactName = [contactName lowercaseString];
    }
    return contactName;
}

-(NSString *) addPeerInfo:(NSString *) userName lowerCase:(BOOL) lowerCase
{
    NSString *fullString;
    if ([userName rangeOfString:@"@" options:NSCaseInsensitiveSearch].location == NSNotFound)
    {
        fullString = [NSString stringWithFormat:@"%@@sip.silentcircle.net",userName];
    } else
    {
        
        if(userName.length > 4 &&  [userName.lowercaseString hasPrefix:@"sip:"]){
            fullString = [NSString stringWithUTF8String:(userName.UTF8String+4)];
        }
        else {
            fullString = userName;
        }
    }
    if(lowerCase)
    {
        fullString = [fullString lowercaseString];
    }
    
    // removes ;x-sc-uuid or anything after ;
    NSArray *arrayWithoutuuid = [fullString componentsSeparatedByString:@";"];
    fullString = arrayWithoutuuid[0];
    return fullString;
}

#pragma mark badge number handling
/*
  Badge numbers stored in nsuserdefaults with format 
 key - contactname, value NSArray of msgid's
 */
-(void) addBadgeNumberWithChatObject:(ChatObject *) thisChatObject
{
    if(!thisChatObject)
        return;
    
    if(thisChatObject.isSynced || thisChatObject.errorString || thisChatObject.isInvitationChatObject)
        return;
    
    @synchronized(self) {
        NSString *fullContactName = [self addPeerInfo:thisChatObject.contactName lowerCase:YES];
        NSMutableArray  *thisContactUnreadMessagesArray = [[_unreadMessages objectForKey:fullContactName] mutableCopy];

        if(!thisContactUnreadMessagesArray)
        {
            thisContactUnreadMessagesArray = [[NSMutableArray alloc] init];
        }
        [thisContactUnreadMessagesArray addObject:thisChatObject.msgId];

        if (fullContactName)
            [_unreadMessages setObject:thisContactUnreadMessagesArray forKey:fullContactName];

        [[NSUserDefaults standardUserDefaults] setObject:_unreadMessages forKey:@"unreadMessages"];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetBadgeNumberNotification
                                                            object:self
                                                          userInfo:@{ kSCPChatObjectDictionaryKey : thisChatObject }];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetAppBadgeNumberNotification
                                                            object:self];
    }
    
    
}

-(void) removeBadgeNumberForChatObject:(ChatObject *) thisChatObject;
{
    if(!thisChatObject)
        return;
    
    @synchronized(self) {
        NSString *fullUserName = [self addPeerInfo:thisChatObject.contactName lowerCase:YES];
       
        NSArray *a =[_unreadMessages objectForKey:fullUserName];
        if (!a) {
            return ;
        }
        NSMutableArray *badgeCountArray = [a mutableCopy];
        
        [badgeCountArray removeObject:thisChatObject.msgId];
        
        // because of mutableCopy
        if (fullUserName)
        {
            [_unreadMessages setObject:badgeCountArray forKey:fullUserName];
            [[NSUserDefaults standardUserDefaults] setObject:_unreadMessages forKey:@"unreadMessages"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetBadgeNumberNotification
                                                            object:self
                                                          userInfo:@{ kSCPChatObjectDictionaryKey : thisChatObject }];

        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetAppBadgeNumberNotification
                                                            object:self];
    }

}

-(void) removeBadgesForConversation:(RecentObject *) thisRecentObject
{
    if(!thisRecentObject)
        return;
    
    @synchronized(self) {
        NSString *fullUserName = [self addPeerInfo:thisRecentObject.contactName lowerCase:YES];
        NSArray *unreadMessagesForThisAccount = (NSArray *)[_unreadMessages objectForKey:fullUserName];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[UIApplication sharedApplication].applicationIconBadgeNumber - unreadMessagesForThisAccount.count];
        if (![_unreadMessages objectForKey:fullUserName])
        {
            return;
        }
        [_unreadMessages removeObjectForKey:fullUserName];
        [[NSUserDefaults standardUserDefaults] setObject:_unreadMessages forKey:@"unreadMessages"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : thisRecentObject }];
    }
}

-(NSString*) getBadgeValueForChatTabBar
{
    int totalBadgeCount = 0;
    for (NSArray *countArr in _unreadMessages.allValues) {
        if(countArr)
        {
            totalBadgeCount += countArr.count;
        }
        
    }
    return [NSString stringWithFormat:@"%i",totalBadgeCount];
}

-(int) getBadgeValueForUser:(NSString *) userName
{
    
    NSArray *badgeArrayForUser = [_unreadMessages objectForKey:[self addPeerInfo:userName lowerCase:YES]];
    if(!userName || !badgeArrayForUser)
        return 0;
    return (int)badgeArrayForUser.count;
}




- (NSString*) takeTimeFromDateStamp:(long) unixTimeStamp
{
    NSDate *dateFromString = [NSDate dateWithTimeIntervalSince1970:unixTimeStamp];
    return [_dateFormatter stringFromDate:dateFromString];
}

- (NSString*) chatListDateFromDateStamp:(long) unixTimeStamp
{
    NSDate *dateFromString = [NSDate dateWithTimeIntervalSince1970:unixTimeStamp];
    return [_chatListDateFormatter stringFromDate:dateFromString];
}

- (NSString*) takeHeaderTitleTimeFromDateStamp:(long) unixTimeStamp
{
    NSDate *dateFromString = [NSDate dateWithTimeIntervalSince1970:unixTimeStamp];
    return [_chatViewHeaderdateFormatter stringFromDate:dateFromString];
}

-(NSString *)getAvatarUrlFromUserOrAlias:(NSString *)user{
    
    if(![Switchboard isZinaReady])
        return nil;
    
    zina::NameLookup *nl = zina::NameLookup::getInstance();
    
    shared_ptr<zina::UserInfo> userInfo = nl->getUserInfo(user.UTF8String, self.apiKey.UTF8String);
    DDLogVerbose(@"getAvatarUrlFromUserOrAlias: (zina) %@", user);
    return (userInfo) ? [NSString stringWithUTF8String:userInfo->avatarUrl.c_str()] : @"";
}

-(NSString *)getUserNameFromAlias:(NSString *)alias{
    
   int cleanPhoneNumber(char *p, int iLen);
   void safeStrCpy(char *dst, const char *name, int iMaxSize);
   
   char buf[128];
   
   safeStrCpy(buf, alias.UTF8String, sizeof(buf)-2);
   cleanPhoneNumber(buf, (int)strlen(buf));
   const char *p1 = &buf[0];
   
   int canModifyNumber(void);
   if(isdigit(p1[0]) && canModifyNumber()){ //if the first char is a digit the we have to have dial assist and add the '+'
      CTNumberHelperBase *dh = g_getDialerHelper();

      NSString *r = (NSString *)[[SCPSettingsManager shared] valueForKey:@"szDialingPrefCountry"];
      
      dh->clear();
      dh->setID(r.UTF8String);
      
      const char *p = dh->tryUpdate(buf);
      p1 = dh->tryRemoveNDD(p);
   }
   
    if(![Switchboard isZinaReady])
        return nil;

   zina::NameLookup *nl = zina::NameLookup::getInstance();
   std::string str = nl->getUid(p1, self.apiKey.UTF8String);
   
   if(str.empty())return @"";
   
   return  [NSString stringWithUTF8String:str.c_str()];
}

-(NSString *)getDisplayNameFromUserOrAlias:(NSString *)user{
    
    if(![Switchboard isZinaReady])
        return nil;
    
   zina::NameLookup *nl = zina::NameLookup::getInstance();
   
   shared_ptr<zina::UserInfo> userInfo = nl->getUserInfo(user.UTF8String, self.apiKey.UTF8String);
    DDLogVerbose(@"getDisplayNameFromUserOrAlias: (zina) %@", user);
   return (userInfo) ? [NSString stringWithUTF8String:userInfo->displayName.c_str()] : @"";
}

-(NSString *)getPrimaryAliasFromUser:(NSString *)user{
   
    if(![Switchboard isZinaReady])
        return nil;
    
   zina::NameLookup *nl = zina::NameLookup::getInstance();
   
   shared_ptr<zina::UserInfo> userInfo = nl->getUserInfo(user.UTF8String, self.apiKey.UTF8String);
    DDLogVerbose(@"getPrimaryAliasFromUser: (zina) %@", user);
   return (userInfo) ? [NSString stringWithUTF8String:userInfo->alias0.c_str()] : @"";
}


-(NSString *) apiKey {
    
    const char *getAPIKey(void);
    
    return [NSString stringWithUTF8String:getAPIKey()];
}

-(NSString *) getTimeDifferenceSinceNowForTimeString:(int) unixTime
{
    // NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
    NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow:0];
    
    NSDateComponents *components = [[NSCalendar currentCalendar] components: NSCalendarUnitHour |NSCalendarUnitMinute|NSCalendarUnitSecond|NSCalendarUnitMonth|NSCalendarUnitYear | NSCalendarUnitDay
                                                                   fromDate: [NSDate dateWithTimeIntervalSince1970:unixTime] toDate: localNow options: 0];
    NSString * timeDifferenceSinceNow;
    
    // check which component is bigger than 0 in descending order
    if([components year] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%liy ago", nil),(long)[components year]];
    }
    else if([components month] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%limon ago", nil),(long)[components month]];
    }
    else if([components day] > 0 && [components day] <10000)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%lid ago", nil),(long)[components day]];
    }
    else if([components hour] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%lih ago", nil),(long)[components hour]];
    }
    else if([components minute] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%limin ago", nil),(long)[components minute]];
    }
    else if ([components second] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:NSLocalizedString(@"%lis ago", nil),(long)[components second]];
    } else
    {
        // if all compnents ar zero - if message just got posted, show word "now"
        timeDifferenceSinceNow = NSLocalizedString(@"now", nil);
    }
    return timeDifferenceSinceNow;
}

-(NSDictionary *) getBurnNoticeRemainingTime:(ChatObject *)thisChatObject
{
    long long burnTime;
    long long unixBurnTime = thisChatObject.isGroupChatObject?thisChatObject.unixCreationTimeStamp:thisChatObject.unixReadTimeStamp;
    
    // if message has not been read, don't compensate extra day or month for displaying
    BOOL shouldCompensateLastDay = YES;
    if(unixBurnTime <= 0)
    {
        shouldCompensateLastDay = NO;
        unixBurnTime = time(NULL);
    }
    burnTime = unixBurnTime + thisChatObject.burnTime;
    
    // doesn't work correctly, returns component day = 3 and hour = 1, when should return day = 3, hour = 0
    /*
    NSDateComponents *components = [[NSCalendar currentCalendar] components: NSCalendarUnitHour |NSCalendarUnitMinute|NSCalendarUnitSecond|NSCalendarUnitMonth|NSCalendarUnitYear | NSCalendarUnitDay
                                                                   fromDate: [NSDate dateWithTimeIntervalSince1970:time(NULL)] toDate: [NSDate dateWithTimeIntervalSince1970:burnTime] options: 0];*/
    
    
    long difference = [[NSDate dateWithTimeIntervalSince1970:burnTime] timeIntervalSinceNow];
    
    NSString *timeToBurn;
    NSString *accessibilityTimeToBurn;
    long componentValue = 0;
   /* if([components year] > 0)
    {
        timeToBurn = [NSString stringWithFormat:@"%liyr",(long)[components year]];
        accessibilityTimeToBurn = [NSString stringWithFormat:@"%liyear",(long)[components year]];
    }
    else if([components month] > 0)
    {
        componentValue = [components month];
        timeToBurn = [NSString stringWithFormat:@"%limo",componentValue];
        accessibilityTimeToBurn = [NSString stringWithFormat:@"%limonth",componentValue];
    }
    else*/ if(difference /(3600 *24) > 0 && difference /(3600 *24) <10000)
    {
        componentValue = difference /(3600 *24) + 1;
        timeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lid", nil),componentValue];
        accessibilityTimeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%liday", nil),componentValue];
    }
    else if(difference / 3600 > 0)
    {
        componentValue = difference / 3600 + 1;
        timeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lih", nil),componentValue];
        accessibilityTimeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lihour", nil),componentValue];
    }
    else if(difference / 60 > 0)
    {
        componentValue = difference / 60 + 1;
        timeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lim", nil),componentValue];
        accessibilityTimeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%liminute", nil),componentValue];
    }
    else if (difference > 0)
    {
        componentValue = difference + 1;
        timeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lis", nil),componentValue];
        accessibilityTimeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%lisecond", nil),componentValue];
    } else
    {
        // if all compnents ar zero - if message just got posted, show word "now"
        timeToBurn = NSLocalizedString(@"now", nil);
        accessibilityTimeToBurn = timeToBurn;
    }
    
    // add plural to accessibility
    if(componentValue > 1)
    {
        accessibilityTimeToBurn = [NSString stringWithFormat:NSLocalizedString(@"%@s", nil),accessibilityTimeToBurn];
    }
    
    
    return [[NSDictionary alloc] initWithObjects:@[timeToBurn, accessibilityTimeToBurn] forKeys:@[@"burnTime",@"accessibilityBurnTime"]];
    
}

-(UIFont *) getMediumFontWithSize:(float) size
{
     return [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
}

-(UIFont *) getBoldFontWithSize:(float) size
{
    return [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
}

-(UIFont*) getFontWithSize:(float) size
{
    return [UIFont fontWithName:@"Helvetica Neue" size:size];
}

-(void) setTimeStampHeight
{
    CGRect timeStampTextRect = [@"Delivered, sodien 10:14" boundingRectWithSize:CGSizeMake([ChatUtilities utilitiesInstance].screenWidth, 9999)
                                                                        options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                                     attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]}
                                                                        context:nil
                                ];
    CGSize timeStampTextSize = CGSizeMake(ceil(timeStampTextRect.size.width), ceil(timeStampTextRect.size.height));
    _timeStampHeight = (long)timeStampTextSize.height;
}

-(int) getBadgeValueWithoutUser:(NSString *) usernameToExclude
{
    usernameToExclude = [self addPeerInfo:usernameToExclude lowerCase:NO];
    int totalBadgeCount = 0;
    
    NSArray *array  = [[DBManager dBManagerInstance] getRecents];
    
    
    for (RecentObject *recent in array) {
        if (![recent.contactName isEqualToString:usernameToExclude]) {
            NSArray *unreadMessageCount = [self.unreadMessages objectForKey:recent.contactName];
            totalBadgeCount += unreadMessageCount.count;
        }
    }
    return totalBadgeCount;
}

-(NSString *) getOwnUserName
{
    void *getAccountByID(int id, int iIsEnabled);
    const char* sendEngMsg(void *pEng, const char *p);
    const char *p = sendEngMsg(getAccountByID(0, 1), "cfg.un");
    return [NSString stringWithUTF8String:p];
}

-(NSString *) getInitialsForUserName:(NSString *) userName
{
    // If userName is nil then bail (yes there are such occassions)
    if(!userName)
        return @"";
    if ([self isNumber:userName]) {
        return @"";
    }
    
    // Trimming spaces that cause issues
    userName = [userName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Removes multiple spaces so that the componentsSeparatedByString: below can work properly and not crash
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
    userName = [regex stringByReplacingMatchesInString:userName options:0 range:NSMakeRange(0, [userName length]) withTemplate:@" "];

    NSString * initials = @"";
    NSArray *initialsArray = [userName componentsSeparatedByString:@" "];
    if(initialsArray.count > 1)
    {
        if(initialsArray.count ==1)
        {
            initials = [initialsArray[0] substringToIndex:1];
        } else if( initialsArray.count > 1)
        {
            initials = [NSString stringWithFormat:@"%@%@", [initialsArray[0] substringToIndex:1],[initialsArray[1] substringToIndex:1]];
        }
    } else
    {
        if(userName.length > 1)
            initials = [userName substringToIndex:2];
        else initials = userName;
    }
    return [initials uppercaseString];
}

-(void) assignSelectedRecent:(NSString *)contactName withProps:(NSDictionary *)propsDict;
{
    NSString *contactNameWithPeerInfo = [self addPeerInfo:contactName lowerCase:YES];

    _selectedRecentObject = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactNameWithPeerInfo];
    if ( (_selectedRecentObject) && (propsDict) ) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[DBManager dBManagerInstance] saveRecentObject:_selectedRecentObject];
        });
    }
}

-(BOOL)isSCUser:(NSString *)contactName {
    
    if([self isUUID:contactName])
        return YES;
    
    return ![self isNumber:contactName];
}

-(BOOL)isEmail:(NSString *)string {
    
    BOOL stricterFilter = NO; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    NSString *stricterFilterString = @"^[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}$";
    NSString *laxString = @"^.+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*$";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:string];
}

-(BOOL)isSipEmail:(NSString *)string {

    return [self isEmail:string] && [string hasSuffix:@"sip.silentcircle.net"];
}

-(BOOL)isNumber:(NSString *)nr{
    
    /** 
     SP: NOTE for potential refactor here
     
     We can use NSDataDetector to detect whether the provided string is (or includes) a phone number or not and extract it
     
     Example:
     
     NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
     
     NSArray *stringsToTest = @[
     @"*3246",
     @"(0030)6987103404",
     @"sip:12024996427",
     @"12024996427",
     @"+12024996427"
     ];
    
     for (NSString *string in stringsToTest)
     {
        NSTextCheckingResult *result = [dataDetector firstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
        NSLog(@"%@", result.phoneNumber);
     }
    */
    if(!nr || nr.length<1)
        return NO;
    
    const char *pN = nr.UTF8String;
    
    const char *sipPrefix           = "sip:";
    const char *silentPhonePrefix   = "silentphone:";
    
    if(strncmp(pN, sipPrefix, strlen(sipPrefix)) == 0)
        pN += strlen(sipPrefix);
    
    if(strncmp(pN, "silentphone:", strlen(silentPhonePrefix)) == 0)
        pN += strlen(silentPhonePrefix);
    
    while(pN[0]=='+' || pN[0]=='(' || pN[0]==' '|| pN[0]=='-' || pN[0]=='*')
        pN++;
    
    if(isdigit(pN[0]))
        return YES;
    
    return NO;
}

-(void) setSavedUnsentNewConversationMessage:(NSString *) messageText forRecentObject:(RecentObject *) recent{
    if (recent.contactName)
    {
        [_savedUnsentNewConversationMessages setObject:@{@"messageText":messageText, @"displayName":recent.displayName, @"contactName":recent.contactName, @"unixTimeStamp":[NSString stringWithFormat: @"%ld", recent.unixTimeStamp]} forKey:[self addPeerInfo:recent.contactName lowerCase:NO]];
        [[NSUserDefaults standardUserDefaults] setObject:_savedUnsentNewConversationMessages forKey:@"savedUnsentNewConversationMessage"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
-(void) removeSavedUnsentNewConversationMessageForContactName:(NSString *) contactName {
    if ([_savedUnsentNewConversationMessages objectForKey:contactName]){
        if (contactName)
        {
            [_savedUnsentNewConversationMessages removeObjectForKey:[self addPeerInfo:contactName lowerCase:NO]];
            [[NSUserDefaults standardUserDefaults] setObject:_savedUnsentNewConversationMessages forKey:@"savedUnsentNewConversationMessage"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

-(void) setSavedMessageText:(NSString *) messageText forContactName:(NSString *) contactName
{
    if (contactName)
    {
        [_savedMessageTexts setObject:messageText forKey:[self addPeerInfo:contactName lowerCase:NO]];
        [[NSUserDefaults standardUserDefaults] setObject:_savedMessageTexts forKey:@"savedMessageTexts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(void) removeSavedMessageTextForContactName:(NSString *) contactName
{
    if (contactName)
    {
        [_savedMessageTexts removeObjectForKey:[self addPeerInfo:contactName lowerCase:NO]];
        [[NSUserDefaults standardUserDefaults] setObject:_savedMessageTexts forKey:@"savedMessageTexts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(NSString *)formatInfoStringForChatObject:(ChatObject *)thisChatObject
{
    NSString *infoString;
    
    long long readTimeStamp;
    if(thisChatObject.unixReadTimeStamp)
        readTimeStamp = thisChatObject.unixReadTimeStamp;
    else
        readTimeStamp = time(NULL);
    
    if ([[ChatUtilities utilitiesInstance] isNumber:thisChatObject.contactName])
    {
        infoString = [NSString stringWithFormat:NSLocalizedString(@"Burn Time: %@", nil), NSLocalizedString(@"Never", nil)];
    } else
    {
        NSString *burnTime = [self iso8601formatForTimestamp:thisChatObject.burnTime + readTimeStamp];
        infoString = [NSString stringWithFormat:NSLocalizedString(@"Burn Time: %@", nil), burnTime];
    }
    
    NSString *contactName = nil;
    NSString *displayName = nil;
    if (thisChatObject.isGroupChatObject)
    {
        contactName = thisChatObject.senderId;
        displayName = thisChatObject.senderDisplayName;
    } else
    {
        contactName = thisChatObject.contactName;
        displayName = thisChatObject.displayName;
    }
    
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nContact name/uuid : %@", nil), contactName]];
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nDisplay name: %@", nil), displayName]];
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nIs Message Read : %@", nil), thisChatObject.isRead ? NSLocalizedString(@"YES", nil) : NSLocalizedString(@"NO", nil)]];
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nIs Message Received : %@", nil), thisChatObject.isReceived ? NSLocalizedString(@"YES", nil) : NSLocalizedString(@"NO", nil)]];
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nIs Message Synced : %@", nil), thisChatObject.isSynced ? NSLocalizedString(@"YES", nil) : NSLocalizedString(@"NO", nil)]];
    infoString = [NSString stringWithFormat:@"%@%@",
                  infoString,
                  [NSString stringWithFormat:NSLocalizedString(@"\n\nMessage ID : %@", nil), thisChatObject.msgId]];
    
    NSString *messageText;
    if(thisChatObject.messageText.length > 0)
    {
        messageText = thisChatObject.messageText;
    } else
    {
        messageText = @"Attachment";
    }
    
    if(thisChatObject.isReceived == 1){
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:NSLocalizedString(@"\n\nComposed time : %@", nil), [self iso8601formatForTimestamp:thisChatObject.timeVal.tv_sec]]];
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:NSLocalizedString(@"\n\nReceived time : %@", nil), [self iso8601formatForTimestamp:thisChatObject.unixTimeStamp]]];
    } else{
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:NSLocalizedString(@"\n\nSent time : %@", nil), [self iso8601formatForTimestamp:thisChatObject.timeVal.tv_sec]]];
    }
    
    if(thisChatObject.unixDeliveryTimeStamp){
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:NSLocalizedString(@"\n\nDelivery time : %@", nil), [self iso8601formatForTimestamp:thisChatObject.unixDeliveryTimeStamp]]];
    }
    if(thisChatObject.isRead && !thisChatObject.isGroupChatObject)
    {
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:NSLocalizedString(@"\n\nRead time : %@", nil), [self iso8601formatForTimestamp:thisChatObject.unixReadTimeStamp]]];
    }
    
    NSString *devicesString = @"";
    if (thisChatObject.preparedMessageData)
    {
        for (NSDictionary *info in thisChatObject.preparedMessageData)
        {
            NSString *deviceName = [info objectForKey:@"deviceName"];
            if (!deviceName || deviceName.length == 0)
            {
                deviceName = NSLocalizedString(@"Unknown", nil);
            }
            scsMessageStatus status = (scsMessageStatus)[[info objectForKey:@"msgState"] longLongValue];
            NSString *statusString =  [ChatUtilities getMessageStatusStringFromEnum:status];
            
            devicesString = [NSString stringWithFormat:@"%@\n %@",devicesString,[NSString stringWithFormat:@"\n %@: %@",deviceName,statusString]];
        }
        
        NSString *deviceInfoTitle = [NSString stringWithFormat:@"\n\nMessage is sent to %lu devices",(unsigned long)thisChatObject.preparedMessageData.count];
        
        infoString = [NSString stringWithFormat:@"%@%@",
                      infoString,
                      [NSString stringWithFormat:@"%@%@",deviceInfoTitle, devicesString]];
    }


    
    return infoString;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    NSString *passWord = [[NSUserDefaults standardUserDefaults] valueForKey:@"lockKey"];
    NSString *thisPassword = [alertView textFieldAtIndex:0].text;
    if(buttonIndex == 1)
    {
        if([passWord isEqualToString:thisPassword])
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lockKey"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [_lockedOverlayView removeFromSuperview];
        } else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Wrong passcode", nil)
                                                            message:NSLocalizedString(@"Enter Passcode", nil)
                                                           delegate:[ChatUtilities utilitiesInstance]
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  otherButtonTitles:NSLocalizedString(@"Turn Off", nil), NSLocalizedString(@"Change Passcode", nil),  NSLocalizedString(@"Change Delay", nil), nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            //[alert textFieldAtIndex:0].delegate = self;
            [alert show];
        }
    }
}

-(void)showLocalAlertFromCall:(SCPCall *)call {
    NSString *contactName = call.bufPeer;
//    if ([contactName length] == 0)
//        contactName = @"(unknown)";
    [self showLocalAlertFromContact:contactName localizedMessage:call.bufMsg];
}

-(void)showLocalAlertFromChatObject:(ChatObject *)thisChatObject
{
    NSString *notificationPref = (NSString *)[[SCPSettingsManager shared] valueForKey:@"szMessageNotifcations"];
    // possibilities: "Notification only,Sender only,Message+Sender
    NSString *message;
    if ([@"Notification only" isEqualToString:notificationPref]) {
        message = NSLocalizedString(@"Message received.", nil);
    } else {
        if ( (thisChatObject.messageText.length > 0) && (![@"Sender only" isEqualToString:notificationPref]) )
            message = thisChatObject.messageText;
        else if (thisChatObject.messageText.length == 0)
            message = NSLocalizedString(@"Sent you an attachment", nil);
        else
            message = NSLocalizedString(@"Sent you a message.", nil);
    }

    [self showLocalAlertFromContact:thisChatObject.contactName localizedMessage:message];
}

- (void)showLocalAlertFromContact:(NSString *)contactName localizedMessage:(NSString *)message {
    if(_isChatThreadVisible) {
        if([[self removePeerInfo:_selectedRecentObject.contactName lowerCase:YES] isEqualToString:[self removePeerInfo:contactName lowerCase:YES]]) {
            return;
        }
    }

    __weak NSString *weakContactName = contactName;
    __weak NSString *weakMessage = message;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong NSString *strongContactName = weakContactName;
        __strong NSString *strongMessage = weakMessage;
        NSString *title = NSLocalizedString(@"Incoming message", nil);
        NSString *initials = @"";
        UIImage *contactImage = nil;

        RecentObject *thisRecent = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:strongContactName];
        NSString *cleanContactName = [self removePeerInfo:strongContactName lowerCase:NO];
        
        NSString *notificationPref = (NSString *)[[SCPSettingsManager shared] valueForKey:@"szMessageNotifcations"];
        BOOL bHideContact = [@"Notification only" isEqualToString:notificationPref];
        if (!bHideContact) {
            // grab and display sender info
            contactImage = [AvatarManager avatarImageForConversationObject:thisRecent size:eAvatarSizeFull];
            if(thisRecent.displayName) {
                title = thisRecent.displayName;
                initials = [self getInitialsForUserName:thisRecent.displayName];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Do not show local alert view if the lockscreen is up or if it should be presented
            // (e.g we are in a call and as the device is locked)
            UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
            
            if([keyWindow.rootViewController isKindOfClass:[MWSPinLockScreenVC class]])
                return;
            
            SCSContainerController *containerController = (SCSContainerController *)keyWindow.rootViewController;
            
            if([containerController shouldShowLockScreen])
                return;
            
            LocalAlertView *alert = [[LocalAlertView alloc] initWithContactName:cleanContactName
                                                                          title:title
                                                                          image:contactImage
                                                                       initials:initials
                                                                        message:strongMessage
                                                                       duration:2.
                                                                    completion:nil];
            alert.hideContact = bHideContact;
            [alert showAlert];
        });
    });
}

- (NSString*) iso8601formatForTimestamp:(long long)unixTimestamp {
    
    return [_dateFormatterISO stringFromDate:[NSDate dateWithTimeIntervalSince1970:unixTimestamp]];
}

-(NSString *)getISO8601Timestamp{
 //  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  // NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  // [dateFormatter setLocale:enUSPOSIXLocale];
  // [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
   
   NSDate *now = [NSDate date];
   return [_dateFormatterISO stringFromDate:now];
}

-(long)getUnixTimeFromISO8601:(NSString *)iso{
  // NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
 //  NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
   
   //[formatter setLocale:posix];
   //[formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
   NSDate *date = [_dateFormatterISO dateFromString:iso];
   if(date == nil) return time(NULL);
   
   return date.timeIntervalSince1970;
}

-(NSString *) getTitleforChatViewSectionFromChatObject:(ChatObject *) thisChatObject
{
    return [self takeHeaderTitleTimeFromDateStamp:thisChatObject.unixTimeStamp];
}

- (BOOL)isDate:(NSDate *) date1 sameDayAsDate:(NSDate*)date2 {
    
    // From progrmr's answer...
    NSCalendar* calendar = [NSCalendar currentCalendar];
    
    unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay;
    NSDateComponents* comp1 = [calendar components:unitFlags fromDate:date1];
    NSDateComponents* comp2 = [calendar components:unitFlags fromDate:date2];
    
    return [comp1 day]   == [comp2 day] &&
    [comp1 month] == [comp2 month] &&
    [comp1 year]  == [comp2 year];
}

-(NSString *)getCallInfoFromCallChatObject:(ChatObject *)thisChatObject
{
    if(thisChatObject.callDuration < 0)
        thisChatObject.callDuration = 0;
    
    NSString *callDurationString = [SCPCall durationStringForCallDuration:thisChatObject.callDuration];
    NSString *callInfoString;
    
    switch (thisChatObject.callState) {
        case eIncomingAnswered:
            callInfoString = NSLocalizedString(@"Incoming call", nil);
            break;
        case eDialedEnded:
        case eDialedNoAnswer:
            callInfoString = NSLocalizedString(@"Outgoing call", nil);
            break;
        case eIncomingMissed:
            callInfoString = NSLocalizedString(@"Missed call", nil);
            break;
        case eIncomingDeclined:
            callInfoString = NSLocalizedString(@"Declined call", nil);
            break;
        default:
            break;
    }
    
    if(thisChatObject.calls.count > 1)
        callInfoString = [callInfoString stringByAppendingString:[NSString stringWithFormat:@" (%lu)", (unsigned long)thisChatObject.calls.count]];
    else if(thisChatObject.callState == eDialedNoAnswer)
        callInfoString = [callInfoString stringByAppendingString:@" (No answer)"];
    else if(thisChatObject.callState != eIncomingMissed && thisChatObject.calls.count <= 1 && thisChatObject.callState != eIncomingDeclined)
        callInfoString = [callInfoString stringByAppendingString:[NSString stringWithFormat:@" (%@)", callDurationString]];
    
    return callInfoString;
}

NSString * const kSC_LastSavedAvatarUserDefaultsKey = @"kSC_LastSavedAvatarUserDefaultsKey";

-(BOOL) profileImageIsCached {
    
    // Check if key exists in NSUserDefaults
    NSString *profileImageKey = [[NSUserDefaults standardUserDefaults] stringForKey:kSC_LastSavedAvatarUserDefaultsKey];
    
    if(!profileImageKey || [profileImageKey isEqualToString:@""])
        return NO;
    
    // Get the last path component from the avatar_url field of the /v1/me call (e.g. /avatar/TwP8uGUwLHT7WEQ7uBA89m/39j7/)
    // and find if this is the last one cached
    if([UserService currentUser] && ![profileImageKey isEqualToString:[self avatarUserDefaultsString]])
        return NO;
    
    // Check if profile image file exists in the NSCachesDirectory
    return [[NSFileManager defaultManager] fileExistsAtPath:[self cachedProfileImagePath]];
}

- (NSString *)cachedProfileImagePath {
    NSString *pathForFile = [[SCFileManager cachesDirectoryURL] URLByAppendingPathComponent:@"profile-image.png"].relativePath;
    return pathForFile;
}


/**
 The value to save in the NSUserDefaults for the avatar url key.
 
 If the avatar url does not exist (user has not set an avatar,
 or he deleted his existing one) then we set this value to an empty string
 in order to know that there is no avatar yet.

 @return The value to be saved in NSUserDefaults.
 */
- (NSString *)avatarUserDefaultsString {

    NSString *avatarUserDefaults = @"";
    
    if([UserService currentUser] &&
       [UserService currentUser].avatarURL &&
       [[UserService currentUser].avatarURL lastPathComponent]) {
        
        avatarUserDefaults = [[UserService currentUser].avatarURL lastPathComponent];
    }
    
    return avatarUserDefaults;
}

- (BOOL) cacheProfileImage {
    
    NSString *avatarURLPath = [UserService currentUser].avatarURL;
    
    if(!avatarURLPath) {
        
        [self clearCachedProfileImage];
        
        NSString *avatarUserDefaultsString = [self avatarUserDefaultsString];
        
        if(avatarUserDefaultsString && ![avatarUserDefaultsString isEqualToString:@""])
            [[NSUserDefaults standardUserDefaults] setObject:avatarUserDefaultsString
                                                      forKey:kSC_LastSavedAvatarUserDefaultsKey];

        return NO;
    }

    NSURL *avatarURL = [ChatUtilities buildApiURLForPath:avatarURLPath];
    UIImage *profileImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:avatarURL]];
    NSData *profileImageData = UIImagePNGRepresentation(profileImage);
    BOOL saved = [profileImageData writeToFile:[self cachedProfileImagePath] atomically:YES];

    if(!saved)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSC_LastSavedAvatarUserDefaultsKey];
    else
        [[NSUserDefaults standardUserDefaults] setObject:[self avatarUserDefaultsString]
                                                  forKey:kSC_LastSavedAvatarUserDefaultsKey];
    
    return saved;
}

-(BOOL) clearCachedProfileImage {
    
    // If there is no file to remove, bail
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self cachedProfileImagePath]])
        return NO;
    
    NSError *error = nil;
    BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:[self cachedProfileImagePath] error:&error];
    
    if(!removed)
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    
    return removed;
}

-(UIImage *) getProfileImage {
    
    BOOL isCached = [self profileImageIsCached];
    
    if(!isCached)
        [self cacheProfileImage];
    
    NSData *profileImageData = [NSData dataWithContentsOfFile:[self cachedProfileImagePath]];
    
    return [UIImage imageWithData:profileImageData];
}

-(BOOL) isUUID:(NSString *) string
{
    string =  [self removePeerInfo:string lowerCase:NO];
   
    if(string.length != 25 && string.length != 26)
    {
        return NO;
    }
    const char* str = string.UTF8String;
    
    if(str[0]!='u')
    {
        return NO;
    }
    str++;
    while(str[0]){
        if(!islower(str[0]) && !isnumber(str[0]))return NO;
        str++;
    }
    return YES;
}

-(NSString *) getDisplayName:(ChatObject *) thisChatObject
{
   if(thisChatObject.displayName && thisChatObject.displayName.length>0){
      return thisChatObject.displayName;
   }
   if([self isUUID:thisChatObject.contactName])
   {
      if(!thisChatObject.displayName)
      {
         // take alias from recentobject
         // get for recentObject from getprimaryalias
      }
      return thisChatObject.displayName;
   } else
   {
      return [self removePeerInfo:thisChatObject.contactName lowerCase:NO];
   }
}

-(NSString *)cleanPhoneNumber:(NSString *) phoneNumber
{
    if(![self isNumber:phoneNumber])
    {
        return phoneNumber;
    }
    int cleanPhoneNumber(char *p, int iLen);
    void safeStrCpy(char *dst, const char *name, int iMaxSize);
    
    char buf[128];
    
    safeStrCpy(buf, phoneNumber.UTF8String, sizeof(buf)-2);
    cleanPhoneNumber(buf, (int)strlen(buf));
    
    
    return [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
}

-(void)askPermissionForSettingWithName:(NSString *)name
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Access to %@ is disabled", nil),name];
        NSString *subtitle = [NSString stringWithFormat:NSLocalizedString(@"You can visit Settings to enable access to %@", nil),name];
        UIAlertController * locationAlert = [UIAlertController
                                             alertControllerWithTitle:title
                                             message:subtitle
                                             preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction
                             actionWithTitle:NSLocalizedString(@"Take me there", nil)
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                 [[UIApplication sharedApplication] openURL:url];
                             }];
        
        UIAlertAction* cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"No, thanks", nil) style:UIAlertActionStyleCancel handler:nil];
        [locationAlert addAction:ok];
        [locationAlert addAction:cancel];
        
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:locationAlert animated:YES completion:nil];
    });

}

-(void) fontDidChange:(NSNotification *) notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPChatBubbleTextSizeChanged object:self];
}

/*
 // example function
 -(void) loginWithUserName:(NSString*) userName completitionBlock:(void (^)(BOOL finished)) completition
 {
 if([userName isEqualToString:@"username"])
 {
 completition(YES);
 } else
 {
 completition(NO);
 }
 }
 [ChatUtilitiesInstance loginWithUserName:@"username" completitionBlock:^(BOOL finished){
 if(finished)
 {
 NSLog(@"i logged in with username");
 } else
 NSLog(@"no username");
 
 }];
 */

#pragma mark - URL builders

+ (NSURL*)buildWebURLForPath:(NSString*)urlPath {
    
    if(!urlPath)
        return nil;
    
    extern const char* getCurrentWebSrv();
    
    NSString *webSrv = [NSString stringWithCString:getCurrentWebSrv()
                                          encoding:NSASCIIStringEncoding];
    
    NSString *fullURLString = [webSrv stringByAppendingString:urlPath];
    
    return [NSURL URLWithString:fullURLString];
}

+ (NSURL*)buildApiURLForPath:(NSString*)urlPath {
    
    if(!urlPath)
        return nil;
    
    extern const char* getCurrentProvSrv();
    
    NSString *apiSrv = [NSString stringWithCString:getCurrentProvSrv()
                                          encoding:NSASCIIStringEncoding];
    
    NSString *fullURLString = [apiSrv stringByAppendingString:urlPath];
    
    return [NSURL URLWithString:fullURLString];
}

+ (NSString *)encodedContact:(NSString *)contact {
    NSString *unformattedContact = [[ChatUtilities utilitiesInstance] cleanPhoneNumber:contact];
    NSString *safeContact = [unformattedContact stringByAddingPercentEncodingForRFC3986];
    
    return safeContact;
}

#pragma mark DR check
-(void) checkIfDRIsBlockingCommunicationWithContactName:(NSString *) contactName completion:(void(^) (BOOL exists, BOOL blocked, SCSDRStatus drStatus)) isBlockingCommunication {
    
    if(!contactName)
        return;
    
    if(!isBlockingCommunication)
        return;

#if !HAS_DATA_RETENTION
    isBlockingCommunication(YES, NO, SCSDRStatusLocalDRDisabled | SCSDRStatusRemoteDRDisabled);
    return;
#else
    
    NSString *contactNameWithPeerInfo = [[[self class] utilitiesInstance] addPeerInfo:contactName
                                                                            lowerCase:YES];
    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:contactNameWithPeerInfo];

    __block SCSDRStatus localDRStatus  = SCSDRStatusLocalDRDisabled;
    __block SCSDRStatus remoteDRStatus = SCSDRStatusRemoteDRDisabled;
    __block BOOL blocked               = NO;

    if([UserService currentUser].drEnabled)
        localDRStatus = SCSDRStatusLocalDREnabled;
    
    if (!recent) {
        
        [self checkIfContactNameExists:contactName
                            completion:^(RecentObject *updatedRecent) {
                                
                                if(updatedRecent) {
                                    
                                    blocked = [UserService isDRBlockedForContact:updatedRecent];
                                    
                                    if(updatedRecent.drEnabled)
                                        remoteDRStatus = SCSDRStatusRemoteDREnabled;
                                }
                                
                                isBlockingCommunication((updatedRecent != nil), blocked, localDRStatus | remoteDRStatus);
                            }];
    }
    else {

        blocked = ([UserService isDRBlockedForContact:recent]);
        if(recent.drEnabled)
            remoteDRStatus = SCSDRStatusRemoteDREnabled;
        isBlockingCommunication(YES, blocked, localDRStatus | remoteDRStatus);
    }
#endif // HAS_DATA_RETENTION
}

#pragma mark - User Existence checking

- (void)checkIfContactNameExists:(NSString *)contactName completion:(void (^)(RecentObject *updatedRecent))completion {
    
    if(!completion)
        return;
    
    RecentObject *existingRecent = [[DBManager dBManagerInstance] getRecentByName:contactName];
    
    if(existingRecent) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(existingRecent);
        });
        
        return;
    }
    
    RecentObject *cachedRecent = [Switchboard.userResolver cachedRecentWithUUID:contactName];
    
    if(cachedRecent) {

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(cachedRecent);
        });
        
        return;
    }
    
    NSString *endpoint = [SCPNetworkManager prepareEndpoint:SCPNetworkManagerEndpointV1User
                                               withUsername:contactName];
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                    useSharedSession:NO
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              
                                              if(error || !httpResponse || httpResponse.statusCode != 200) {
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      completion(nil);
                                                  });
                                                  
                                                  return;
                                              }
                                              
                                              RecentObject *recent = [[RecentObject alloc] initWithJSON:responseObject];
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completion(recent);
                                              });

                                              if(recent) {
                                                  
                                                  [[SCSContactsManager sharedManager] linkConversationWithContact:recent];
                                                  
                                                  [Switchboard.userResolver donateRecentToCache:recent];
                                              }
                                          }];
}

using namespace zina;
-(BOOL)areAllDevicesVerifiedWithRecentObject:(RecentObject *) recentObject
{
    NSString *username = [[ChatUtilities utilitiesInstance] removePeerInfo:recentObject.contactName lowerCase:NO];

    int unverifiedDevices = 0;
    
    if ([self isNumber:username])
        return NO;
    
    AppInterfaceImpl *app;
    app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    
    if(app == NULL)
        return NO;
    
    string myUn = app->getOwnUser();
    shared_ptr<list<string> > listMy = app->getIdentityKeys(myUn);
    
    string un(username.UTF8String);
    shared_ptr<list<string> > listPeer = app->getIdentityKeys(un);
    
    if (listPeer->empty() && listMy->empty())
        return NO;

    while (!listPeer->empty()) {
            
        std::string resultStr = listPeer->front();
        NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
        NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
        
        if (deviceInfoArray.count >= 3) {
            NSString *isVerified = deviceInfoArray[3];
            
            // we have found an unverified device
            if (isVerified.intValue != 2 ) {
                unverifiedDevices ++;
            }
        }
        
        listPeer->erase(listPeer->begin());
    }

    NSString *ownDeviceInfo = [NSString stringWithUTF8String:app->getOwnIdentityKey().c_str()];
    NSArray *ownDeviceInfoArray = [ownDeviceInfo componentsSeparatedByString:@":"];
    
    while (!listMy->empty()) {
        
        std::string resultStr = listMy->front();
        NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
        NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
        
        if(![(NSString *)ownDeviceInfoArray[0] isEqualToString:(NSString *)deviceInfoArray[0]]) {
            if (deviceInfoArray.count >= 3) {
                NSString *isVerified = deviceInfoArray[3];
                if (isVerified.intValue != 2) {
                    unverifiedDevices ++;
                }
            }
        }
        
        listMy->erase(listMy->begin());
    }

    return (unverifiedDevices == 0);
}


+(NSString *) getMessageStatusStringFromEnum:(scsMessageStatus) status
{
    NSString *statusString = @"Unknown";
    switch (status) {
        case 0:
            statusString = @"Sent";
            break;
        case 1:
            statusString = @"Delivered";
            break;
        case 2:
            statusString = @"Received";
            break;
        case 3:
            statusString = @"Read";
            break;
        case 5:
            statusString = @"Sync";
            break;
        case 6:
            statusString = @"Failed";
            break;

            
        default:
            break;
    }
    return statusString;
}

- (NSString *)firstNameFromFullName:(NSString *)fullName {
    
    if(!fullName)
        return nil;
    
    NSArray * separatedName = [fullName componentsSeparatedByString:@" "];
    
    if (separatedName.count > 0)
        return separatedName[0];

    return fullName;
}

-(void)getPrimaryAliasAndDisplayName:(NSString *)contactName completion:(void (^)(NSString *, NSString *))completion
{
    __block NSString *contactNameWithoutPeerInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:YES];
    NSString *contactNameWithPeerInfo = [[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES];
    
    NSString *ownUserName = [[[self class] utilitiesInstance] getOwnUserName];
    if ([contactNameWithoutPeerInfo isEqualToString:ownUserName])
    {
        completion([UserService currentUser].displayName,[UserService currentUser].displayAlias);
        return;
    }
    [[SCSContactsManager sharedManager] addressBookContactWithInfo:contactNameWithPeerInfo
                                                        completion:^(AddressBookContact *contact)
    {
        if(contact)
        {
            completion(contact.fullName,nil);
            return;
        }
    
        // dont try to get displayname and avatar for number conversations
        if([[ChatUtilities utilitiesInstance] isNumber:contactNameWithoutPeerInfo])
        {
            completion(contactNameWithoutPeerInfo,nil);
            
            // dont save recentobject at this point, because of recursive call when taking recents out of database
            // instead assign it each time a conversation without displayname get's taken out of database
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            BOOL online = [Switchboard.networkManager hasNetworkConnection];
            if (online) {
                
                if (contactNameWithoutPeerInfo)
                {
                    if ([[ChatUtilities utilitiesInstance] isUUID:contactNameWithoutPeerInfo])
                    {
                        NSString *displayAlias = [[ChatUtilities utilitiesInstance] getPrimaryAliasFromUser:contactNameWithoutPeerInfo];
                        NSString *displayName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:contactNameWithoutPeerInfo];
                            completion(displayName,displayAlias);
                    } else
                    {
                        NSString *displayName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:contactNameWithoutPeerInfo];
                        completion(displayName,contactNameWithoutPeerInfo);
                    }
                }
            }
        });
    }];
}

-(NSString *)getBurnValueStringFromSeconds:(int)seconds
{
    for (int i = 0; i<self.allBurnValues.count; i+=2)
    {
        int burnValue = [self.allBurnValues[i] intValue];
        if (burnValue == seconds / 60)
        {
            if (self.allBurnValues.count > i+1)
            {
                NSString *burnString = self.allBurnValues[i+1];
                return burnString;
            }
        }
    }
    return @"";
}

#pragma mark - Interaction Donation

- (BOOL)donateInteractionWithIntent:(INIntent *)intent {
    
    if(![INIntent class])
        return NO;
    
    if(!intent)
        return NO;
    
    INIntentResponse *response = [INIntentResponse new];
    
    INInteraction *interaction = [[INInteraction alloc] initWithIntent:intent
                                                              response:response];
    [interaction setDirection:INInteractionDirectionOutgoing];
    [interaction donateInteractionWithCompletion:nil];
    
    return YES;
}

- (BOOL)donateInteractionWithAddressBookContact:(AddressBookContact *)addressBookContact {

    if(!addressBookContact)
        return NO;
    
    if(![INIntent class])
        return NO;

    if(!addressBookContact.displayAlias)
        return NO;
    
    INPersonHandleType handleType = INPersonHandleTypeUnknown;
    
    NSString *peerAddress = [[SCSContactsManager sharedManager] cleanContactInfo:addressBookContact.displayAlias];
    
    BOOL isNumber = [self isNumber:peerAddress];

    if([self isEmail:peerAddress] && ![self isSipEmail:peerAddress])
        handleType = INPersonHandleTypeEmailAddress;
    else if(isNumber)
        handleType = INPersonHandleTypePhoneNumber;
    
    INPersonHandle *recipientHandle = [[INPersonHandle alloc] initWithValue:peerAddress
                                                                       type:handleType];
    
    INPerson *recipient = [[INPerson alloc] initWithPersonHandle:recipientHandle
                                                  nameComponents:nil
                                                     displayName:addressBookContact.fullName
                                                           image:nil
                                               contactIdentifier:addressBookContact.cnIdentifier
                                                customIdentifier:nil];

    INIntent *audioCallIntent   = [[INStartAudioCallIntent alloc] initWithContacts:@[ recipient ]];
    INIntent *videoCallIntent   = [[INStartVideoCallIntent alloc] initWithContacts:@[ recipient ]];
    INIntent *sendMessageIntent = [[INSendMessageIntent alloc] initWithRecipients:@[ recipient ]
                                                                          content:nil
                                                                        groupName:nil
                                                                      serviceName:nil
                                                                           sender:nil];
    
    [self donateInteractionWithIntent:audioCallIntent];
    [self donateInteractionWithIntent:videoCallIntent];
    [self donateInteractionWithIntent:sendMessageIntent];
    
    return YES;
}

- (BOOL)donateInteractionWithRecent:(RecentObject *)recent doesExistInDirectory:(BOOL)doesExist {
    
    if(!recent)
        return NO;
    
    if(![INIntent class])
        return NO;
    
    if(!recent.abContact)
        return NO;
    
    if(!recent.displayAlias)
        return NO;
    
    NSString *peerAddress = [[SCSContactsManager sharedManager] cleanContactInfo:recent.displayAlias];
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:peerAddress];
    
    if(!isNumber && !doesExist)
        return NO;
    
    INPersonHandleType handleType = INPersonHandleTypeUnknown;
    
    if([[ChatUtilities utilitiesInstance] isEmail:peerAddress] && ![[ChatUtilities utilitiesInstance] isSipEmail:peerAddress])
        handleType = INPersonHandleTypeEmailAddress;
    else if(isNumber)
        handleType = INPersonHandleTypePhoneNumber;
    
    INPersonHandle *recipientHandle = [[INPersonHandle alloc] initWithValue:peerAddress
                                                                       type:handleType];
    
    INPerson *recipient = [[INPerson alloc] initWithPersonHandle:recipientHandle
                                                  nameComponents:nil
                                                     displayName:recent.displayName
                                                           image:nil
                                               contactIdentifier:recent.abContact.cnIdentifier
                                                customIdentifier:nil];
    
    INIntent *intent = nil;
    
    if(isNumber)
        intent = [[INStartAudioCallIntent alloc] initWithContacts:@[ recipient ]];
    else
        intent = [[INSendMessageIntent alloc] initWithRecipients:@[ recipient ]
                                                         content:nil
                                                       groupName:nil
                                                     serviceName:nil
                                                          sender:nil];

    return [self donateInteractionWithIntent:intent];
}

+(UIButton *) getNavigationBarBackButton
{
    int backButtonSize = [[self class] getNavigationBarButtonSize];
    UIButton *arrowButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [arrowButton setFrame:CGRectMake(0,0,backButtonSize,backButtonSize)];
    [arrowButton setImage:[UIImage navigationBarBackButton] forState:UIControlStateNormal];
    arrowButton.accessibilityLabel = @"Close";
    return arrowButton;
}

+(int)getNavigationBarButtonSize
{
    return 30;
}



-(void) showNoNetworkErrorForConversation:(RecentObject *) conversation actionType:(scsActionType) actionType
{
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName lowerCase:YES];
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:uuid];
    
    NSString *actionString = nil;
    NSString *actionTitle = nil;
    if (actionType == eCall || isNumber)
    {
        actionString = kFailedToCall;
        actionTitle = kUnableToCall;
    }
    else
    {
        actionString = kFailedToWrite;
        actionTitle = kUnableToSendMessages;
    }
    NSString *alertMessage = [NSString stringWithFormat:@"%@\n%@\n\n%@",actionString,uuid,kEnsureNetwork];
    UIAlertController *noNetworkAlert = [UIAlertController alertControllerWithTitle:actionTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"OK", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action)
                               {
                                   [noNetworkAlert dismissViewControllerAnimated:YES completion:nil];
                               }];
    
    [noNetworkAlert addAction:okAction];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:noNetworkAlert animated:YES completion:nil];
}


@end
