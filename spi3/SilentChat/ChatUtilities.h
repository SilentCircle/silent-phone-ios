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
/**
 * Singleton for storing Chat data and getting phone variables
 **/

/*
 *
 * 10/23/15 Renamed file because of collision with axolotl utilities class
 *
 */

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AddressBookContact.h"
#import "SCSEnums.h"


//static NSString * const kSCPNewChatMessageNotification          = @"kSCPNewChatMessageNotification";

typedef NS_OPTIONS(NSInteger, SCSDRStatus) {
    SCSDRStatusLocalDRDisabled  = (1 << 0),
    SCSDRStatusLocalDREnabled   = (1 << 1),
    SCSDRStatusRemoteDRDisabled = (1 << 2),
    SCSDRStatusRemoteDREnabled  = (1 << 3)
};

@class RecentObject;
@class ChatObject;
@class SCPCall;

@interface ChatUtilities : NSObject

+(ChatUtilities*)utilitiesInstance;

// screen
@property float screenWidth;
@property float screenHeight;

// userLocation
@property (nonatomic, strong) CLLocation *userLocation;

// bool flag to open chat view only once when responding to incoming notification
// for some reason AppDelegate's didReceiveLocalNotification: gets called more than once when opening app from notification
@property BOOL shouldOpenChatViewFromNotification;


//chatHistory
//@property (nonatomic, strong) NSMutableDictionary *chatHistory;

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSDateFormatter *chatListDateFormatter;
@property (nonatomic, strong) NSDateFormatter *chatViewHeaderdateFormatter;

@property (nonatomic, strong) NSDateFormatter *dateFormatterISO;
@property (nonatomic, strong) NSLocale *enUSPOSIXLocaleISO;
@property (nonatomic, strong) NSCalendar *gregorianCalendar;

//messageBurning
@property int savedBurnStateIndex;


// id of last opened Chat user
//@property (nonatomic, strong) NSString *lastOpenedUserIDForChat;

// name of last opened Chat user
//@property (nonatomic, strong) NSString *lastOpenedUserNameForChat;

// recents table objects
//@property (nonatomic, strong) NSMutableDictionary *recents;

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


/*
 Checks text for url
 used in chat to detect if text messages contain url
 */
-(BOOL) existsUrlInText:(NSString *)text;



// dictionary of badge numbers for received unread messages
// stored in nsuserdefaults
// Key = username, value = unread received message count
//@property (nonatomic, strong) NSMutableDictionary *receivedMessageBadges;


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





// takes time out of timestamp
// format - 11:45:39
- (NSString*) takeTimeFromDateStamp:(long) unixTimeStamp;

// format - 12/12/2015
- (NSString*) chatListDateFromDateStamp:(long) unixTimeStamp;

// takes time out of timestamp for chat view header title
// format - today, monday 14:59
- (NSString*) takeHeaderTitleTimeFromDateStamp:(long) unixTimeStamp;


// returns badge number as NSString for user
-(int) getBadgeValueForUser:(NSString *) userName;


-(BOOL) isUUID:(NSString *) string;

-(NSString *)getUserNameFromAlias:(NSString *)alias;

/**
 * Delete all message badges with contact when conversation gets deleted
 **/
-(void) removeBadgesForConversation:(RecentObject *) thisRecentObject;

/**
 * returns Users APIKey as NSString
 **/
-(NSString *) apiKey;


/**
 * Calculate time difference from ChatObject.timestamp to now
 *@param timeString - NSDATE in NSString format
 *@return TimeDifference in format  1s ago, 1m ago, 1h ago ..
 **/
-(NSString *) getTimeDifferenceSinceNowForTimeString:(int) unixTime;


/**
 * returns burn notice time in nsstring format 1s, 1m,1h ...
 * for group messages uses message creation time and for normal messages uses message read time
 **/
-(NSDictionary *) getBurnNoticeRemainingTime:(ChatObject*) thisChatObject;

//@property (nonatomic, strong) NSMutableDictionary *burnTimers;


@property (nonatomic, strong) UIFont *appFont;
/**
 * App general font getter
 **/
-(UIFont*) getFontWithSize:(float) size;

/**
 * App title font getter
 **/
-(UIFont *) getMediumFontWithSize:(float) size;

/**
 * App selected title font getter
 **/
-(UIFont *) getBoldFontWithSize:(float) size;



// return my username
-(NSString *) getOwnUserName;


//saved mkmaptype
@property int savedMapType;

// saved flag for show location on mapviews
@property int savedShowLocationState;

// the call count
@property int callCnt;

// forwarded message content
//Contains 2 keys forwardedChatObject and forwardedRecentObject when message is being forwarded
@property (nonatomic, strong) NSMutableDictionary *forwardedMessageData;


// chatobject to be replaced when updated object with same msgid comes in
@property (nonatomic, strong) ChatObject *chatObjectWithError;

/**
 * Returns badgevalue for chatview back button, excluding opened username
 **/
-(int) getBadgeValueWithoutUser:(NSString *) usernameToExclude;

// displays alertview asking to go to settings and allow access to item name
-(void) askPermissionForSettingWithName:(NSString *)name;

/*
 * Assigns new selectedRecentObject with default values or takes it from recents array
 */
-(void) assignSelectedRecent:(NSString *)contactName withProps:(NSDictionary *)propsDict;

-(NSString *)getISO8601Timestamp;
-(long)getUnixTimeFromISO8601:(NSString *)iso;


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

@property (nonatomic, strong) NSMutableDictionary *savedUnsentNewConversationMessages;

/*
 * Sets value and key for savedMessageTexts
 * Attempts to mimic setvalueForKey: setters
 */
-(void) setSavedMessageText:(NSString *) messageText forContactName:(NSString *) contactName;
-(void) removeSavedMessageTextForContactName:(NSString *) contactName;


-(void) setSavedUnsentNewConversationMessage:(NSString *) messageText forRecentObject:(RecentObject *) recent;
-(void) removeSavedUnsentNewConversationMessageForContactName:(NSString *) contactName;

/*
 * Returns initials for conversation
 *if no display name or surname is not present, take first two letters of contactname
 */
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

/*
 Shows local alert for incoming message
 Doesnt show notification if user has opened message thread with the same user
 */
-(void)showLocalAlertFromChatObject:(ChatObject *) thisChatObject;

/**
 Shows local alert for a call
 Doesn't show notification if user has opened message thread with the same user
 @param call a call object
 */
-(void)showLocalAlertFromCall:(SCPCall *)call;


/**
 Shows local alert for a contact
 Will attempt to lookup contact avatar

 @param contactName contactName in SPI
 @param localizedMessage localized message
 */
- (void)showLocalAlertFromContact:(NSString *)contactName localizedMessage:(NSString *)message;


@property (nonatomic) BOOL isChatThreadVisible;



- (BOOL)isDate:(NSDate *) date1 sameDayAsDate:(NSDate*)date2;


@property (nonatomic, strong) UIImage *receivedMessageBackground;
@property (nonatomic, strong) UIImage *sentMessageBackground;

@property (nonatomic, strong) UIImage *callBubbleBackground;
@property (nonatomic, strong) UIImage *missedCallBubbleBackground;

-(NSString *)getCallInfoFromCallChatObject:(ChatObject *)thisChatObject;


/*
 Burn messages for whom actual messages doesn't exist yet
 If this array contains a record compare each received message for records in this array to check if burn 
 has been received for incoming message, if burn exists, dont save received message and remove record from array
 
 Stored in NSUserdefaults for now
 */
@property (nonatomic, strong) NSMutableArray *stackedBurns;

/*
 Keeps burn and read messages which are sent when there is no network available,
 resend them when network comes online
 stored in NSUserDefaults
 
 contains ChatObjects
 */
//move this to db
@property (nonatomic, strong) NSMutableDictionary *stackedOfflineBurns;
@property (nonatomic, strong) NSMutableDictionary *stackedOfflineReads;

- (BOOL) clearCachedProfileImage;
/*
 downloads profile image and saves it in documents directory with the username.png
 */
-(UIImage *) getProfileImage;

-(NSString *) getDisplayName:(ChatObject *) thisChatObject;
-(NSString *)getDisplayNameFromUserOrAlias:(NSString *)user;
-(NSString *)getPrimaryAliasFromUser:(NSString *)user;

// how many messages should be loaded from database in each loading step
@property int kMessageLoadingCount;


// called when font changes to resize all chatbubbles containing text
-(void) fontDidChange:(NSNotification *) notification;





-(NSString *)getAvatarUrlFromUserOrAlias:(NSString *)user;
@property (nonatomic, strong) NSOperationQueue *avatarDownloadQueue;

//-(void) getDisplayNameAndAvatarForRecentObject:(RecentObject*)thisRecent;

/**
 Heuristic method that checks a given name if it belongs to a SC user
 without making an API call.
 
 Internally it first calls the (heuristic) method isUUID: and if this returns false,
 it calls the (heuristic again) isNumber: method for the given contactName.
 
 @param contactName A contact name (typically the contactName property of the RecentObject object. The method removes the peer info internally in the isUUID: check.
 @return YES if the contact name is considered to be a SC user, NO otherwise.
 */
-(BOOL)isSCUser:(NSString *)contactName;

-(BOOL)isNumber:(NSString *)nr;

-(BOOL)isEmail:(NSString *)string;

-(BOOL)isSipEmail:(NSString *)string;

//@property (nonatomic) (enum scsFilterState) conversationFilter;
@property (nonatomic) int conversationFilter;

-(NSString *)cleanPhoneNumber:(NSString *) phneNumber;

@property (nonatomic, strong) NSMutableDictionary * unreadMessages;

/**
 Use this method to build a full url for a given urlPath for accounts.silentcircle.com links.
 
 DO NOT prefix those urls manually, use this class method instead which adds the correct host
 depending on whether the production or the development server should be used.
 
 @see buildApiURLForPath: for API methods
 @param urlPath The path that needs to be prefixed. It must contain a leading slash (e.g. /terms/) and it must be already url encoded if necessary.
 @return The full Web URL
 */
+ (NSURL*)buildWebURLForPath:(NSString*)urlPath;

/**
 Use this method to build a full url for a given urlPath for sccps.silentcircle.com API calls.
 
 DO NOT prefix those urls manually, use this class method instead which adds the correct host
 depending on whether the production or the development server should be used.
 
 @see buildWebURLForPath: for Web links
 @param urlPath The path that needs to be prefixed. It must contain a leading slash (e.g. /v1/me/) and it must be already url encoded if necessary.
 @return The full API URL
 */
+ (NSURL*)buildApiURLForPath:(NSString*)urlPath;

+ (NSString *)encodedContact:(NSString *)contact;

/**
 * Checks if a given contact name exists either in the conversations list or in Silent Circle
 *
 * The method performs an async calls and calls the completion function in the main thread when it finishes.
 *
 * @param contactName The contact name we want to search for
 * @param completion The callback function to be called upon completion
 */
- (void)checkIfContactNameExists:(NSString *) contactName completion:(void (^)(RecentObject *updatedRecent))completion;

/**
 Check if DR should block communication with this recentobject
 */
-(void) checkIfDRIsBlockingCommunicationWithContactName:(NSString *) contactName completion:(void(^) (BOOL exists, BOOL blocked, SCSDRStatus drStatus)) isBlockingCommunication;

/**
 * Stops any on-going checks for a contact name
 */
- (void)stopCheckingForContactName;

/*
 Checks verified flag for all devices in conversation with given recentObject
 */
-(BOOL)areAllDevicesVerifiedWithRecentObject:(RecentObject *) recentObject;



+(NSString *) getMessageStatusStringFromEnum:(scsMessageStatus) status;

/*
 Contains functionality from getPrimaryAliasAndDisplayName from RecentObject
 Downloads display name and displayAlias for uuid contactnames
 This was removed from RecentObject to get displaynames for group members when there are no Conversation with given contactName or if RecentObject is local reference
 */
- (void)getPrimaryAliasAndDisplayName:(NSString *) contactName completion:(void (^)(NSString *displayName, NSString *displayAlias))completion;

// Array of all burn values
// contains burn values in pairs
// first index is string of minutes
// folowing index is string of same value in verbal string

// example:
// allBurnValues[0] = @"1";
// allBurnValues[1] = @"1 minute";
@property (nonatomic, strong) NSArray *allBurnValues;

/*
 Returns verbal string for burn seconds
 */
-(NSString *) getBurnValueStringFromSeconds:(int) seconds;

/**
 Donates an AddressBookContact as an interaction to the system.

 @param addressBookContact The AddressBookContact instance that is going to be donated
 @return YES if the donation has been made, NO otherwise
 */
- (BOOL)donateInteractionWithAddressBookContact:(AddressBookContact *)addressBookContact;

/**
 Donates a RecentObject as an interaction to the system.

 @param recent The RecentObject instance that is going to be donated
 @param doesExist Whether the RecentObject exists or not in the SC directory
 @return YES if the donation has been made, NO otherwise
 */
- (BOOL)donateInteractionWithRecent:(RecentObject *)recent doesExistInDirectory:(BOOL)doesExist;

/*
 Returns first name from passed full name
 e.g. Returns Gints for Gints Osis
 */
-(NSString *)firstNameFromFullName:(NSString *) fullName;

- (NSString*) iso8601formatForTimestamp:(long long)unixTimestamp;


// Navigation bar back button getter
+(UIButton *) getNavigationBarBackButton;
+(int) getNavigationBarButtonSize;



/**
 Shows alertView about unreachable network when trying to call or write a message to new user

 @param conversation conversation on which action was performed
 @param actionType call or write to user
 */
-(void) showNoNetworkErrorForConversation:(RecentObject *) conversation actionType:(scsActionType) actionType;

@end
