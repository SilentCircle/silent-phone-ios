/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#import "Utilities.h"
#import "ChatObject.h"
#import "DBManager.h"
#import <AudioToolbox/AudioServices.h>
#import "SP_FastContactFinder.h"

@implementation Utilities
+(Utilities *)utilitiesInstance
{
    static dispatch_once_t once;
    static Utilities *utilitiesInstance;
    dispatch_once(&once, ^{
        utilitiesInstance = [[self alloc] init];
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        utilitiesInstance.screenHeight = screenRect.size.height;
        utilitiesInstance.screenWidth = screenRect.size.width;
        utilitiesInstance.chatHistory = [[NSMutableDictionary alloc] init];
        utilitiesInstance.recents = [[NSMutableDictionary alloc] init];
        utilitiesInstance.burnTimers = [[NSMutableDictionary alloc] init];
        
        utilitiesInstance.kNavigationBarColor = [UIColor colorWithRed:54/255.0f green:55/255.0f blue:59/255.0f alpha:1.0f];
        utilitiesInstance.kChatViewBackgroundColor = [UIColor colorWithRed:54/255.0f green:55/255.0f blue:59/255.0f alpha:1.0f];
        utilitiesInstance.kStatusBarColor = utilitiesInstance.kNavigationBarColor;
        utilitiesInstance.kAlertPointBackgroundColor = [UIColor colorWithRed:239/225.0 green:39/225.0 blue:27/225.0 alpha:1.0f];
        utilitiesInstance.kStatusBarHeight = 20;
        utilitiesInstance.receivedMessageBadges = [[NSMutableDictionary alloc] init];
        utilitiesInstance.forwardedMessageData = [[NSMutableDictionary alloc] initWithCapacity:2];
        utilitiesInstance.kDefaultBurnTime = 60 * 60 *24 *3;
        
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
        
        utilitiesInstance.dateFormatter = [[NSDateFormatter alloc] init];
        [utilitiesInstance.dateFormatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
        [utilitiesInstance.dateFormatter setTimeStyle:kCFDateFormatterNoStyle];
        [utilitiesInstance.dateFormatter setDoesRelativeDateFormatting:YES];
        [utilitiesInstance.dateFormatter setDateStyle:kCFDateFormatterMediumStyle];
        [utilitiesInstance.dateFormatter setTimeStyle:kCFDateFormatterShortStyle];
        
        utilitiesInstance.allChatObjects = [[NSMapTable alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:utilitiesInstance
                                                 selector:@selector(updateAppBadge:)
                                                     name:@"updateAppBadge" object:nil];
        });
    
    return utilitiesInstance;
}

-(void)updateAppBadge:(NSNotification*)notification {
    
    int chats = [[self getBadgeValueForChatTabBar] intValue];
    
    NSString *badgeNumberStr = [[NSUserDefaults standardUserDefaults] objectForKey:@"badgeNumberForRecents"];
    int badgeNumber = 0;
    if(badgeNumberStr)
    {
        badgeNumber = [badgeNumberStr intValue];
    }
    
    int total = chats + badgeNumber;
    [UIApplication sharedApplication].applicationIconBadgeNumber = total;
}

#pragma mark domain name handling for username string
-(NSString *) removePeerInfo:(NSString*) fullString lowerCase:(BOOL) lowerCase
{
    NSString *contactName;
    NSArray *splitContactNameArr;
    if ([fullString rangeOfString:@"@" options:NSCaseInsensitiveSearch].location != NSNotFound)
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
    return fullString;
}

#pragma mark badge number handling
-(void) addBadgeNumberWithChatObject:(ChatObject *) thisChatObject
{
    if(thisChatObject.isSynced)
        return;
    NSString *fullContactName = [self addPeerInfo:thisChatObject.contactName lowerCase:YES];
    NSHashTable *thisContactUnreadMessagesArray = [_receivedMessageBadges objectForKey:fullContactName] ;
    
    if(!thisContactUnreadMessagesArray)
    {
        thisContactUnreadMessagesArray = [[NSHashTable alloc] init];
        [_receivedMessageBadges setValue:thisContactUnreadMessagesArray forKey:fullContactName];
    }
    [thisContactUnreadMessagesArray addObject:thisChatObject.msgId];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"resetBadgeNumberForChatView" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateAppBadge" object:nil];


}

-(void) removeBadgeNumberForChatObject:(ChatObject *) thisChatObject;
{

    NSString *fullUserName = [self addPeerInfo:thisChatObject.contactName lowerCase:YES];
    NSHashTable *badgeCountArray = [_receivedMessageBadges objectForKey:fullUserName] ;
    if(![badgeCountArray containsObject:thisChatObject.msgId])
    {
        return;
    }
    
    [badgeCountArray removeObject:thisChatObject.msgId];
 /*
    [_receivedMessageBadges setValue:badgeCountArray forKey:thisChatObject.contactName];
    
    [[NSUserDefaults standardUserDefaults] setValue:_receivedMessageBadges forKey:@"receivedMessageBadges"];
    [[NSUserDefaults standardUserDefaults] synchronize];
  */
    [[NSNotificationCenter defaultCenter] postNotificationName:@"resetBadgeNumberForChatView" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateAppBadge" object:nil];
}

-(void) removeBadgesForConversation:(RecentObject *) thisRecentObject
{
    NSString *fullUserName = [self addPeerInfo:thisRecentObject.contactName lowerCase:YES];
    [_receivedMessageBadges removeObjectForKey:fullUserName];
    
    //[[NSUserDefaults standardUserDefaults] setValue:_receivedMessageBadges forKey:@"receivedMessageBadges"];
    //[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*) getBadgeValueForChatTabBar
{
    int totalBadgeCount = 0;
    for (NSArray *countArr in _receivedMessageBadges.allValues) {
        if(countArr)
        {
            totalBadgeCount += countArr.count;
        }

    }
    return [NSString stringWithFormat:@"%i",totalBadgeCount];
}

-(int) getBadgeValueForUser:(NSString *) userName
{
    
    NSArray *badgeArrayForUser = [_receivedMessageBadges objectForKey:[self addPeerInfo:userName lowerCase:YES]];
    if(badgeArrayForUser)
    {
       return (int)badgeArrayForUser.count;

    } else
    {
        return 0;
    }
}

#pragma mark ChatObject finding

-(ChatObject*) getChatObjectByMessageIdentifier:(long long) messageIdentifier
{
    messageIdentifier &= ~15; //clean last 4 bits
    for (NSArray *thisChatObjectArray in _chatHistory.allValues) {
        for (ChatObject *thisChatObject in thisChatObjectArray) {
            if(thisChatObject.messageIdentifier == messageIdentifier)
            {
                return thisChatObject;
            }
        }
    }
    return nil;
}

-(ChatObject*) getChatObjectByMsgId:(NSString *) msgId andContactName:(NSString *) contactName
{
    NSArray *thisContactsChatHistory = [_chatHistory objectForKey:contactName];
    if(thisContactsChatHistory)
    {
            for (ChatObject *thisChatObject in thisContactsChatHistory) {
                if([thisChatObject.msgId isEqualToString: msgId])
                {
                    if(thisChatObject.iDidBurnAnimation || thisChatObject.burnNow)return nil;
                    return thisChatObject;
                }
            }
    }
    return nil;
}

-(void) findAndReplaceChatObjectWithObject:(ChatObject *) thisChatObject
{
    for (NSMutableArray *thisChatObjectArray in _chatHistory.allValues) {
        for (int i = 0;i<thisChatObjectArray.count;i++) {
            ChatObject *current = (ChatObject*)thisChatObjectArray[i];
            

            if(current == thisChatObject)
            {
                [thisChatObjectArray setObject:thisChatObject atIndexedSubscript:i];
                [_chatHistory setValue:thisChatObjectArray forKey:thisChatObject.contactName];
                break;
            }
        }
    }
}

- (NSString*) takeTimeFromDateStamp:(long) unixTimeStamp
{
    NSDate *dateFromString = [NSDate dateWithTimeIntervalSince1970:unixTimeStamp];    
    return [_dateFormatter stringFromDate:dateFromString];
}

-(NSString *)getHttpWithUrl:(NSString *)url method:(NSString *)method requestData:(NSString *) requestData{
    
    NSString *response = @"";
    char* t_send_http_json(const char *url, const char *meth,  char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent);
    
    int iSizeOfRet = 64 * 1024;
    char *retBuf = new char [iSizeOfRet];
    int iContentLen = 0;
    
    char *content = t_send_http_json (url.UTF8String, method.UTF8String,
                                      retBuf ,iSizeOfRet - 2,
                                      iContentLen, requestData.UTF8String);
    
    if(content && iContentLen>0){
        content[iContentLen] = 0;
        response = [NSString stringWithUTF8String:content];
    }
    
    delete retBuf;
    //puts(response->c_str());
    if(iContentLen<1)return @"";
    return response;
}

-(NSString *) getV1_user:(NSString *)user{
   NSString * url = [NSString stringWithFormat:@"/v1/user/%@/?api_key=%@",user,[self getAPIKey]];
   NSString *returnString = [self getHttpWithUrl:url method:@"GET" requestData:@""];
   
   return returnString;
}

-(NSString *)getUserNameFromAlias:(NSString *)alias{
   
   NSString *returnString = [self getV1_user:alias];
   
   if(!returnString || returnString.length<1)return @"";
   
   NSData *data = [returnString dataUsingEncoding:NSUTF8StringEncoding];
   NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                              options:kNilOptions
                                                                error:nil];
   if(!json)return @"";
   
   if([[json objectForKey:@"result"] isEqualToString:@"error"]){
      return @"";
   }
   return json[@"primary_alias"];
}

-(NSString *) getAPIKey
{
    const char *getAPIKey(void);
    NSString *apiKey = [NSString stringWithUTF8String:getAPIKey()];
    
    return apiKey;
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
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%liy ago",(long)[components year]];
    }
    else if([components month] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%lid ago",(long)[components day]];
    }
    else if([components day] > 0 && [components day] <10000)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%lid ago",(long)[components day]];
    }
    else if([components hour] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%lih ago",(long)[components hour]];
    }
    else if([components minute] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%lim ago",(long)[components minute]];
    }
    else if ([components second] > 0)
    {
        timeDifferenceSinceNow = [NSString stringWithFormat:@"%lis ago",(long)[components second]];
    } else
    {
        // if all compnents ar zero - if message just got posted, show word "now"
        timeDifferenceSinceNow = @"now";
    }
    return timeDifferenceSinceNow;
}

-(NSString *) getBurnNoticeRemainingTime:(ChatObject *)thisChatObject
{
    
    long burnTime;
    long unixBurnTime = thisChatObject.unixReadTimeStamp;
    if(unixBurnTime <= 0)
        unixBurnTime = time(NULL);
    burnTime = unixBurnTime + thisChatObject.burnTime;
    NSDateComponents *components = [[NSCalendar currentCalendar] components: NSCalendarUnitHour |NSCalendarUnitMinute|NSCalendarUnitSecond|NSCalendarUnitMonth|NSCalendarUnitYear | NSCalendarUnitDay
                                                                   fromDate: [NSDate dateWithTimeIntervalSince1970:time(NULL)] toDate: [NSDate dateWithTimeIntervalSince1970:burnTime] options: 0];
    
   // NSDateComponents* dayComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitDay
             //                                  fromDate: [NSDate dateWithTimeIntervalSince1970:time(NULL)] toDate: [NSDate dateWithTimeIntervalSince1970:burnTime] options: 0];
    
    NSString *timeToBurn;
    long componentValue = 0;
    if([components year] > 0)
    {
        timeToBurn = [NSString stringWithFormat:@"%liyear",(long)[components year]];
    }
    else if([components month] > 0)
    {
        componentValue = [components month];
        
        // compensate for 3 days showing 2 days 23 hours - 2d
        if([components hour] > 0)
        {
            componentValue += 1;
        }
        timeToBurn = [NSString stringWithFormat:@"%limon",componentValue];
    }
    else if([components day] > 0 && [components day] <10000)
    {
        componentValue = [components day];
        if([components hour] > 0)
        {
            componentValue += 1;
        }
        timeToBurn = [NSString stringWithFormat:@"%lid",componentValue];
    }
    else if([components hour] > 0)
    {
        timeToBurn = [NSString stringWithFormat:@"%lih",(long)[components hour]];
    }
    else if([components minute] > 0)
    {
        timeToBurn = [NSString stringWithFormat:@"%limin",(long)[components minute]];
    }
    else if ([components second] > 0)
    {
        timeToBurn = [NSString stringWithFormat:@"%lisec",(long)[components second]];
    } else
    {
        // if all compnents ar zero - if message just got posted, show word "now"
        timeToBurn = @"now";
    }
    
    
    return timeToBurn;

}

-(void) invalidateBurnTimers
{
    // invalidate and remove burn timers when user closes app
    NSMutableArray *burnTimersArr = [_burnTimers.allValues mutableCopy];
    for (NSTimer *timer in burnTimersArr) {
        [timer invalidate];
    }
    [_burnTimers removeAllObjects];
}

-(UIFont*) getFontWithSize:(float) size
{
    return [UIFont fontWithName:@"avenir" size:size];
}

-(void) setTimeStampHeight
{
    CGRect timeStampTextRect = [@"Delivered, sodien 10:14" boundingRectWithSize:CGSizeMake([Utilities utilitiesInstance].screenWidth, 9999)
                                                                                options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                                             attributes:@{NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]}
                                                                                context:nil
                                ];
    CGSize timeStampTextSize = CGSizeMake(ceil(timeStampTextRect.size.width), ceil(timeStampTextRect.size.height));
    _timeStampHeight = (long)timeStampTextSize.height *1.5f;
}

-(int) getBadgeValueWithoutUser:(NSString *) usernameToExclude
{
    usernameToExclude = [self addPeerInfo:usernameToExclude lowerCase:NO];
    int totalBadgeCount = 0;
    for (NSString *key in _receivedMessageBadges.allKeys) {
        NSArray *badgeArray = [_receivedMessageBadges objectForKey:key];
        if(badgeArray)
        {
            if(![key isEqualToString:usernameToExclude])
            {
                totalBadgeCount +=badgeArray.count;
            }
        }
        
    }
    return totalBadgeCount;
}

-(void) playSoundFile:(NSString *) fileName withExtension:(NSString *) extension
{
    SystemSoundID messageInID = 0;
    NSURL *messageInURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                                      pathForResource: fileName
                                                      ofType: extension] isDirectory:NO];
        
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)messageInURL, &messageInID);
    AudioServicesPlaySystemSound(messageInID);
}

-(NSString *) getOwnUserName
{
    void *getCurrentDOut(void);
    const char* sendEngMsg(void *pEng, const char *p);
    const char *p=sendEngMsg(getCurrentDOut(),"cfg.un");
    return [NSString stringWithUTF8String:p];
}

-(NSString *) getInitialsForUser:(RecentObject *) thisRecent
{
    NSString *initials;
    
    int idx;
    NSString *ns = [SP_FastContactFinder findPerson:thisRecent.contactName idx:&idx];
    
    
    
    if(ns && ns.length > 0)
    {
        initials = [self getInitialsForUserName:ns];
    } else
    {
        if(thisRecent.displayName)
        {
            initials = [self getInitialsForUserName:thisRecent.displayName];
        } else
        {
            initials = [self getInitialsForUserName:thisRecent.contactName];
        }
    }
    return [initials uppercaseString];
}

-(NSString *) getInitialsForUserName:(NSString *) userName
{
    NSString * initials = @"";
    NSArray *initialsArray = [userName componentsSeparatedByString:@" "];
    if(initialsArray.count > 1)
    {
        //initials = [NSString stringWithFormat:@"%@%@",[initialsArray[0] substringToIndex:1], [initialsArray[1] substringToIndex:1]];
        for (NSString *string in initialsArray) {
            if(string.length > 0)
                initials = [NSString stringWithFormat:@"%@%@",initials, [string substringToIndex:1]];
        }
    } else
    {
        if(userName.length > 1)
            initials = [userName substringToIndex:2];
        else initials = userName;
    }
    return initials;
}


-(void) assignSelectedRecentWithContactName:(NSString *) contactName
{
    NSString *contactNameWithPeerInfo = [self addPeerInfo:contactName lowerCase:YES];
    NSString *contactNameWithoutPeerInfo = [self removePeerInfo:contactName lowerCase:NO];
    RecentObject *selectedRecent = [_recents objectForKey:contactNameWithPeerInfo];
    if(!selectedRecent)
    {
        selectedRecent = [[RecentObject alloc] init];
        selectedRecent.burnDelayDuration = _kDefaultBurnTime;
        selectedRecent.contactName = contactNameWithPeerInfo;
        selectedRecent.shareLocationTime = 0;
        int idx;
        NSString *ns = [SP_FastContactFinder findPerson:contactNameWithPeerInfo idx:&idx];
        if(ns)
        {
            selectedRecent.displayName = ns;
        }
        [_recents setValue:selectedRecent forKey:contactNameWithPeerInfo];
    }
    if(!selectedRecent.displayName)
    {
        selectedRecent.displayName = contactNameWithoutPeerInfo;
    }
    _selectedRecentObject = selectedRecent;
}

-(void) setTabBarHidden:(BOOL) isHidden
{
    [self.appDelegateTabBar setHidden:isHidden];
}

-(void) setSavedMessageText:(NSString *) messageText forContactName:(NSString *) contactName
{
    [_savedMessageTexts setValue:messageText forKey:[self addPeerInfo:contactName lowerCase:NO]];
    [[NSUserDefaults standardUserDefaults] setObject:_savedMessageTexts forKey:@"savedMessageTexts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void) removeSavedMessageTextForContactName:(NSString *) contactName
{
    [_savedMessageTexts removeObjectForKey:[self addPeerInfo:contactName lowerCase:NO]];
    [[NSUserDefaults standardUserDefaults] setValue:_savedMessageTexts forKey:@"savedMessageTexts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString *)formatInfoStringForChatObject:(ChatObject *)thisChatObject
{
    NSString *infoString;
    
    long readTimeStamp;
    if(thisChatObject.unixReadTimeStamp)
        readTimeStamp = thisChatObject.unixReadTimeStamp;
    else
        readTimeStamp = time(NULL);
    NSString *burnTime = [self takeTimeFromDateStamp:thisChatObject.burnTime + readTimeStamp];
    infoString = [NSString stringWithFormat:@"%@ : %@",@"Burn Time: ",burnTime];
    
    infoString = [NSString stringWithFormat:@"%@\n\nContact name : %@",infoString, thisChatObject.contactName];
    
    infoString = [NSString stringWithFormat:@"%@\n\n Is Message Read : %@",infoString,thisChatObject.isRead ? @"YES" : @"NO"];
    
    infoString = [NSString stringWithFormat:@"%@\n\n Is Message Received : %@",infoString,thisChatObject.isReceived ? @"YES" : @"NO"];
    
    infoString = [NSString stringWithFormat:@"%@\n\n Is Message Synced : %@",infoString,thisChatObject.isSynced ? @"YES" : @"NO"];
    
    NSString *messageText;
    if(thisChatObject.messageText.length > 0)
    {
        messageText = thisChatObject.messageText;
    } else
    {
        messageText = @"Attachment";
    }
    infoString = [NSString stringWithFormat:@"%@\n\n Message text : %@",infoString, messageText];
    
    if(thisChatObject.isReceived == 1)
    {
         infoString = [NSString stringWithFormat:@"%@\n\n Received time : %@",infoString, [self takeTimeFromDateStamp:thisChatObject.unixTimeStamp]];
    } else
    {
       infoString = [NSString stringWithFormat:@"%@\n\n Sent time : %@",infoString, [self takeTimeFromDateStamp:thisChatObject.timeVal.tv_sec]];
    }

    if(thisChatObject.isRead)
        infoString = [NSString stringWithFormat:@"%@\n\n Read Time : %@",infoString, [self takeTimeFromDateStamp:thisChatObject.unixReadTimeStamp]];

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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wrong passcode" message:@"Enter Passcode" delegate:[Utilities utilitiesInstance] cancelButtonTitle:@"Cancel" otherButtonTitles:@"Turn Off",@"Change Passcode",[NSString stringWithFormat:@"%@",@"Change Delay"], nil];
            alert.alertViewStyle = UIAlertViewStylePlainTextInput;
            //[alert textFieldAtIndex:0].delegate = self;
            [alert show];
        }
    }
}


-(NSString *) formatPhoneNumber:(NSString *)ns{
    
    if(ns == nil)
        return nil;
    
    char buf[64];
    int fixNR(const char *in, char *out, int iLenMax);
    if(fixNR(ns.UTF8String,&buf[0],63)){
        return [NSString stringWithUTF8String:&buf[0]];
    }
    return ns;
}
-(void)showLocalAlertFromUser:(ChatObject *) thisChatObject
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        /*
        
        Alert *alert = [[Alert alloc] initWithTitle:thisChatObject.contactName image:nil initials:<#(NSString *)#> duration:<#(CGFloat)#> completion:<#^(void)completion#>*/
        /*
        Alert *alert = [[Alert alloc] initWithTitle:@"Incoming message" duration:1.0 completion:^{
            //Custom code here after Alert disappears
        }];*/
        /*
        [alert setShowStatusBar:NO];
        [alert showAlert];*/
    });
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
 [utilitiesInstance loginWithUserName:@"username" completitionBlock:^(BOOL finished){
 if(finished)
 {
 NSLog(@"i logged in with username");
 } else
 NSLog(@"no username");
 
 }];
 */
@end
