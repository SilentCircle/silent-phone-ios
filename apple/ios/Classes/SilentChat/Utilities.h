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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "ChatObject.h"
#import "RecentObject.h"

#import "TabBarWithSeperators.h"
#import "Alert.h"
@interface Utilities : NSObject
+(Utilities*)utilitiesInstance;

// screen
@property float screenWidth;
@property float screenHeight;

// userLocation
@property (nonatomic, strong) CLLocation *userLocation;

//chatHistory
@property (nonatomic, strong) NSMutableDictionary *chatHistory;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

//messageBurning
@property int savedBurnStateIndex;


// id of last opened Chat user
//@property (nonatomic, strong) NSString *lastOpenedUserIDForChat;

// name of last opened Chat user
//@property (nonatomic, strong) NSString *lastOpenedUserNameForChat;

// recents table objects
@property (nonatomic, strong) NSMutableDictionary *recents;

@property (nonatomic, strong) RecentObject *selectedRecentObject;

/**
 * Removes @sip.silentcircle.net from username
 * Returns string in lowercase
 **/
-(NSString *) removePeerInfo:(NSString*) fullString lowerCase:(BOOL) lowerCase;

/**
 *add @sip.silentcicle.net to string
 **/
-(NSString *) addPeerInfo:(NSString *) userName lowerCase:(BOOL) lowerCase;


// dictionary of badge numbers for received unread messages
// stored in nsuserdefaults
// Key = username, value = unread received message count
@property (nonatomic, strong) NSMutableDictionary *receivedMessageBadges;
-(void) addBadgeNumberWithChatObject:(ChatObject *) thisChatObject;
-(void) removeBadgeNumberForChatObject:(ChatObject *) thisChatObject;

// return string of number to display in badge
-(NSString*) getBadgeValueForChatTabBar;

@property int kDefaultBurnTime;
// global constants, defined in .m file
@property int kStatusBarHeight;
@property (nonatomic, strong) UIColor *kNavigationBarColor;
@property (nonatomic, strong) UIColor *kChatViewBackgroundColor;
@property (nonatomic, strong) UIColor *kAlertPointBackgroundColor;
@property (nonatomic, strong) UIColor *kStatusBarColor;


// return chatobject by message identifier
-(ChatObject*) getChatObjectByMessageIdentifier:(long long) messageIdentifier;

//find and replace ChatObject with new data
-(void) findAndReplaceChatObjectWithObject:(ChatObject *) thisChatObject;


// takes time out of timestamp
// format - 11:45:39
- (NSString*) takeTimeFromDateStamp:(long) unixTimeStamp;


// returns badge number as NSString for user
-(int) getBadgeValueForUser:(NSString *) userName;

/**
 * Network call
 * @param url - url after slash
 * @param method - GET,POST
 * @param requestData - if method is GET @""
 **/
-(NSString *)getHttpWithUrl:(NSString *)url method:(NSString *)method requestData:(NSString *) requestData;

-(NSString *) getV1_user:(NSString *)user; //or alias
-(NSString *)getUserNameFromAlias:(NSString *)alias;

/**
 * Delete all message badges with contact when conversation gets deleted
 **/
-(void) removeBadgesForConversation:(RecentObject *) thisRecentObject;
/**
 * returns Users APIKey as NSString
 **/
-(NSString *) getAPIKey;

/**
 * find chatObject by msgid and contactname
 **/
-(ChatObject*) getChatObjectByMsgId:(NSString *) msgId andContactName:(NSString *) contactName;

/**
 * Calculate time difference from ChatObject.timestamp to now
 *@param timeString - NSDATE in NSString format
 *@return TimeDifference in format  1s ago, 1m ago, 1h ago ..
 **/
-(NSString *) getTimeDifferenceSinceNowForTimeString:(int) unixTime;


/**
 * returns burn notice time in nsstring format 1s, 1m,1h ...
 **/
-(NSString *) getBurnNoticeRemainingTime:(ChatObject*) thisChatObject;

@property (nonatomic, strong) NSMutableDictionary *burnTimers;


@property (nonatomic, strong) UIFont *appFont;
/**
 * App font getter
 **/
-(UIFont*) getFontWithSize:(float) size;


/**
 * removes all burnTimers
 **/
-(void) invalidateBurnTimers;

// return my username
-(NSString *) getOwnUserName;


//saved mkmaptype
@property int savedMapType;

// saved flag for show location on mapviews
@property int savedShowLocationState;


// forwarded message content
//Contains 2 keys forwardedChatObject and forwardedRecentObject when message is being forwarded
@property (nonatomic, strong) NSMutableDictionary *forwardedMessageData;


// HashTable of all chatobjects msgid,
// used to fast find anychatobject by msgid
// populated from ChatObject msgid setter
@property (nonatomic, strong) NSMapTable *allChatObjects;


// chatobject to be replaced when updated object with same msgid comes in
@property (nonatomic, strong) ChatObject *chatObjectWithError;

/**
 * Returns badgevalue for chatview back button, excluding opened username
 **/
-(int) getBadgeValueWithoutUser:(NSString *) usernameToExclude;

-(void) playSoundFile:(NSString *) fileName withExtension:(NSString *) extension;


/*
 * Assigns new selectedRecentObject with default values or takes it from recents array
 */
-(void) assignSelectedRecentWithContactName:(NSString *) contactName;


/*
 * sets tab bar hidden 
 * Dont use hidesTabbarWhenPushed ever
 */
-(void) setTabBarHidden:(BOOL) isHidden;
@property (nonatomic, strong) TabBarWithSeperators *appDelegateTabBar;


// local file link from openUrl
@property (nonatomic, strong) NSURL *deepLinkUrl;


// formats and returns formatted message details string in format
// key : value
// key : value
-(NSString *) formatInfoStringForChatObject:(ChatObject *) thisChatObject;

/*
 * Unsent written messages for user
 * key - username, value - text
 */
@property (nonatomic, strong) NSMutableDictionary *savedMessageTexts;

/*
 * Sets value and key for savedMessageTexts
 * Attempts to mimic setvalueForKey: setters
 */
-(void) setSavedMessageText:(NSString *) messageText forContactName:(NSString *) contactName;
-(void) removeSavedMessageTextForContactName:(NSString *) contactName;

/*
 * Returns initials for conversation
 *if no display name or surname is not present, take first two letters of contactname
 */
-(NSString *) getInitialsForUser:(RecentObject *) thisRecent;
-(NSString *) getInitialsForUserName:(NSString *) userName;


// reference to dialpad action buttons view to reposition it's frame after call, FIX dialpad action buttons going under tabbar
@property (nonatomic, strong) UIView *dialPadActionButtonView;


// lock key for chat and recents, set in settings
@property (nonatomic, strong) NSString *lockKey;


// black view covering the screen when lock is on
@property (nonatomic, strong) UIView *lockedOverlayView;
// flag to enable lock setting in security tab
@property (nonatomic) BOOL isLockEnabled;


// height of timestamplabel in chatobject
@property (nonatomic) long timeStampHeight;

-(void) setTimeStampHeight;

-(NSString *) formatPhoneNumber:(NSString *)ns;


-(void)showLocalAlertFromUser:(ChatObject *) thisRecent;


@end
