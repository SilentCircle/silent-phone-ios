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
//  SCPNotificationsManager.m
//  SPi3
//
//  Created by Stelios Petrakis on 01/11/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioServices.h>

#import "SCPNotificationsManager.h"
#import "SCSAudioManager.h"
#import "SCPNotificationKeys.h"
#import "AppDelegate.h"
#import "AttachmentManager.h"
#import "ChatUtilities.h"
#import "SCAttachment.h"
#import "SCPCallManager.h"
#import "SCPSettingsManager.h"
#import "SCSContactsManager.h"
#import "SCSEnums.h"
#import "AddressBookContact.h"

static NSString * const kSCPNotificationsAnswerActionIdentifier         = @"ANSWER";
static NSString * const kSCPNotificationsDeclineActionIdentifier        = @"DECLINE";
static NSString * const kSCPNotificationsEndActionIdentifier            = @"END_CALL";
static NSString * const kSCPNotificationsAcceptVideoActionIdentifier    = @"ACCEPT_VIDEO";
static NSString * const kSCPNotificationsDeclineVideoActionIdentifier   = @"DECLINE_VIDEO";

static NSString * const kSCPNotificationsIncomingCategoryIdentifier     = @"INCOMING_CALL_NOTIFICATION";
static NSString * const kSCPNotificationsEndCategoryIdentifier          = @"CALL_NOTIFICATION";
static NSString * const kSCPNotificationsVideoRequestCategoryIdentifier = @"VIDEO_REQUEST_NOTIFICATION";

static NSString * const kSCPNotificationsDefaultSound               = @"kSCPNotificationsDefaultSound";

static NSString * const kSCPNotificationUserInfoTypeKey             = @"kSCPNotificationUserInfoTypeKey";

typedef NS_ENUM(NSInteger, scsNotificationType) {
    kSCSNotificationTypeUnknown = -1,
    kSCSNotificationTypeCall,
    kSCSNotificationTypeMessage
};

@interface SCPNotificationsManager () <UNUserNotificationCenterDelegate> {
    BOOL _userNotificationsSupported;
}
@end

@implementation SCPNotificationsManager

#pragma mark - Lifecycle

- (instancetype)init {
    
    if (self = [super init]) {

        if([UNUserNotificationCenter class])
            _userNotificationsSupported = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - Notifications

-(void)applicationDidEnterBackground:(NSNotification *)notification {
    
    [ChatUtilities utilitiesInstance].shouldOpenChatViewFromNotification = YES;
}

#pragma mark - Private

-(id)scheduleNotificationWithTitle:(NSString *)title body:(NSString *)body type:(scsNotificationType)type identifier:(NSString *)identifier threadIdentifier:(NSString *)threadIdentifier attachment:(SCAttachment *)attachment category:(NSString *)categoryIdentifier ringtone:(NSString *)ringtone {
    
    if(_userNotificationsSupported) {
        
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        
        if(title)
            [content setTitle:title];
        
        if(body)
            [content setBody:body];

        if(ringtone) {
            
            UNNotificationSound *sound = nil;
            
            if([ringtone isEqualToString:kSCPNotificationsDefaultSound])
                sound = [UNNotificationSound defaultSound];
            else
                sound = [UNNotificationSound soundNamed:ringtone];
            
            if(sound)
                [content setSound:sound];
        }
        
        if(categoryIdentifier)
            [content setCategoryIdentifier:categoryIdentifier];
        
        if(threadIdentifier)
            [content setThreadIdentifier:threadIdentifier];
        
        [content setUserInfo:@{ kSCPNotificationUserInfoTypeKey : @(type) }];
        
        if(attachment) {
            
            [[AttachmentManager sharedManager] downloadAttachmentTOC:attachment
                                                       withMessageID:identifier
                                                     completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                         
                                                         if (error) {
                                                             
                                                             [self dispatchUserNotificationWithIdentifier:identifier
                                                                                                  content:content];
                                                             return;
                                                         }

                                                         NSString *attachmentMimeType = [[attachment metadata] objectForKey:kSCloudMetaData_MimeType];
                                                         NSArray *thumbnailMimeTypes = @[@"application/pdf",
                                                                                         @"image/jpeg",
                                                                                         @"image/png",
                                                                                         @"video/mp4",
                                                                                         @"video/quicktime"];
                                                         
                                                         BOOL attachmentHasThumbnail = [thumbnailMimeTypes containsObject:attachmentMimeType];
                                                         
                                                         if(!attachmentHasThumbnail) {
                                                             
                                                             [self dispatchUserNotificationWithIdentifier:identifier
                                                                                                  content:content];
                                                             return;
                                                         }
                                                         
                                                         // Save the attachment thumbnail in the temp directory
                                                         NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()
                                                                                       isDirectory:YES];
                                                         
                                                         NSURL *attachmentURL = [[tmpDirURL URLByAppendingPathComponent:identifier] URLByAppendingPathExtension:@"png"];
                                                         NSData *pngData = UIImagePNGRepresentation([attachment thumbnailImage]);
                                                         
                                                         [pngData writeToFile:[attachmentURL path]
                                                                   atomically:YES];
                                                         
                                                         UNNotificationAttachment *notificationAttachment = [UNNotificationAttachment attachmentWithIdentifier:identifier
                                                                                                                                                           URL:attachmentURL
                                                                                                                                                       options:nil
                                                                                                                                                         error:nil];
                                                         
                                                         [content setAttachments:@[notificationAttachment]];
                                                         
                                                         [self dispatchUserNotificationWithIdentifier:identifier
                                                                                              content:content];
                                                     }];
        }
        else
            [self dispatchUserNotificationWithIdentifier:identifier
                                                 content:content];
        
        return nil;
    }
    else {
        
        UILocalNotification *notification = [UILocalNotification new];
        
        if (!notification)
            return nil;
        
        if(title && !body)
            notification.alertBody = [NSString stringWithFormat: NSLocalizedString(@"%@", nil), title];
        else if(body && !title)
            notification.alertBody = [NSString stringWithFormat: NSLocalizedString(@"%@", nil), body];
        if(title && body)
            notification.alertBody = [NSString stringWithFormat: NSLocalizedString(@"%@\n%@", nil), title, body];
        
        if(categoryIdentifier)
            notification.category = categoryIdentifier;
        
        if(ringtone) {
            
            if([ringtone isEqualToString:kSCPNotificationsDefaultSound])
                notification.soundName = UILocalNotificationDefaultSoundName;
            else
                notification.soundName = ringtone;
        }
        
        NSMutableDictionary *userInfo = [NSMutableDictionary new];
        
        [userInfo setObject:@(type) forKey:kSCPNotificationUserInfoTypeKey];
        
        if(identifier)
            [userInfo setObject:identifier forKey:@"identifier"];
        
        notification.repeatInterval = 0;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        
        return notification;
    }
}

-(void)dispatchUserNotificationWithIdentifier:(NSString *)identifier content:(UNMutableNotificationContent *)content {
    
    if(!identifier)
        return;
    
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1f
                                                                                                    repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                          content:content
                                                                          trigger:trigger];
    
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:^(NSError * _Nullable error) {
                                                               
                                                               if(error)
                                                                   NSLog(@"%s error: %@", __PRETTY_FUNCTION__, error);
                                                           }];
}

-(void)notifyActiveCallForSecurity:(SCPCall *)call {
    
    if ([UIApplication sharedApplication].applicationState ==  UIApplicationStateActive)
        return;
    
    id notification = [self scheduleNotificationWithTitle:NSLocalizedString(@"Call in progress", nil)
                                                     body:NSLocalizedString(@"Unlock screen to check security", nil)
                                                     type:kSCSNotificationTypeCall
                                               identifier:call.uniqueCallId
                                         threadIdentifier:nil
                                               attachment:nil
                                                 category:kSCPNotificationsEndCategoryIdentifier
                                                 ringtone:nil];
    if(notification)
        [call setActiveCallNotif:(UILocalNotification *)notification];
}

-(void)handleCallNotificationActionWithIdentifier:(NSString *)actionIdentifier forCall:(SCPCall *)call {
    
    [SPCallManager stopRingtone:call
                 showMissedCall:![actionIdentifier isEqualToString:kSCPNotificationsAnswerActionIdentifier]
                      forceStop:NO];
    
    if(!call)
        return;
    
    if ([actionIdentifier isEqualToString:kSCPNotificationsAnswerActionIdentifier]) {
        
        [SPCallManager answerCall:call];
        [self notifyActiveCallForSecurity:call];
    }
    else if ([actionIdentifier isEqualToString:kSCPNotificationsDeclineActionIdentifier] ||
             [actionIdentifier isEqualToString:kSCPNotificationsEndActionIdentifier]) {
        
        [SPCallManager terminateCall:call];
    }
    else if([actionIdentifier isEqualToString:kSCPNotificationsAcceptVideoActionIdentifier]) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPCallAcceptedVideoRequestNotification
                                                            object:self
                                                          userInfo:@{ kSCPCallDictionaryKey : call }];
        
    }
    else if([actionIdentifier isEqualToString:kSCPNotificationsDeclineVideoActionIdentifier]) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPCallDeclinedVideoRequestNotification
                                                            object:self
                                                          userInfo:@{ kSCPCallDictionaryKey : call }];
    }
}

-(void)handleMessageNotificationActionForContactName:(NSString *)contactName {
    
    if (!contactName)
        return;
    
    if (![ChatUtilities utilitiesInstance].shouldOpenChatViewFromNotification)
        return;
    
    [ChatUtilities utilitiesInstance].shouldOpenChatViewFromNotification = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPNeedsTransitionToChatWithContactNameNotification
                                                        object:self 
                                                      userInfo:@{ kSCPContactNameDictionaryKey : contactName}];
}

-(void)presentIncomingMessageNotificationForChatObject:(ChatObject *)chatObject withDisplayName:(NSString *)displayName {
    NSString *notificationBody = nil;
    BOOL showAttachment = NO;

    NSString *mn = (NSString *)[[SCPSettingsManager shared] valueForKey:@"szMessageNotifcations"];
    if ([@"Notification only" isEqualToString:mn]) {
        if (chatObject.isGroupChatObject == 1)
            notificationBody = NSLocalizedString(@"You have a new group message", nil);
        else
            notificationBody = NSLocalizedString(@"You have a new message", nil);
    } else if ([@"Sender only" isEqualToString:mn]) {
        if (chatObject.isGroupChatObject == 1) {
            NSString *firstName = [[ChatUtilities utilitiesInstance] firstNameFromFullName:chatObject.senderDisplayName];
            notificationBody = [NSString stringWithFormat:NSLocalizedString(@"Message from %@ in group %@", nil), firstName,chatObject.displayName];
        } else
            notificationBody = [NSString stringWithFormat:NSLocalizedString(@"Message from %@", nil), displayName];
    }
    else {
        // message + sender
        showAttachment = YES;
        
        if ([chatObject.messageText length] == 0)
            notificationBody = [NSString stringWithFormat:NSLocalizedString(@"Attachment from: %@", nil), displayName];
        else if(chatObject.isGroupChatObject == 1)
        {
            NSString *firstName = [[ChatUtilities utilitiesInstance] firstNameFromFullName:chatObject.senderDisplayName];
            notificationBody = [NSString stringWithFormat:NSLocalizedString(@"Message %@ from %@ in group %@", nil),chatObject.messageText, firstName,chatObject.displayName];
        }
        else
            notificationBody = [NSString stringWithFormat:NSLocalizedString(@"%@: %@", nil), displayName, chatObject.messageText];
    }
    
    SCSettingsItem *playSetting = [[SCPSettingsManager shared] settingForKey:@"iPlaySoundNotifications"];
    BOOL playSound = [playSetting boolValue];
    
    NSString *textToneString = nil;
    
    if(playSound) {
        
        NSArray *userSelectedTextTone = [SPAudioManager userSelectedTextTone];
        
        if(userSelectedTextTone)
            textToneString = [userSelectedTextTone componentsJoinedByString:@"."];
        else
            textToneString = kSCPNotificationsDefaultSound;
    }
    
    [self scheduleNotificationWithTitle:nil
                                   body:notificationBody
                                   type:kSCSNotificationTypeMessage
                             identifier:(_userNotificationsSupported ? chatObject.msgId : chatObject.contactName)
                       threadIdentifier:chatObject.contactName
                             attachment:(showAttachment ? chatObject.attachment : nil)
                               category:nil
                               ringtone:textToneString];
}

#pragma mark - SystemPermissionManagerDelegate
/**
 Registers the app for notifications.
 
 Supports both old and new framework.
 
 Called when app launches and user is already provisioned or as soon as user successfully provisions (in order to show the Notifications permissions alert).
 */
- (void)performPermissionCheck {
    
    NSString *answerTitle       = NSLocalizedString(@"Answer", nil);
    NSString *declineTitle      = NSLocalizedString(@"Decline", nil);
    NSString *endTitle          = NSLocalizedString(@"End call", nil);
    NSString *acceptVideoTitle  = NSLocalizedString(@"Accept", nil);
    NSString *declineVideoTitle = NSLocalizedString(@"Ignore", nil);
    
    if(_userNotificationsSupported) {
        
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
            completionHandler:^(BOOL granted, NSError * _Nullable error) {
                [SystemPermissionManager permissionCheckComplete:self];
                if(error)
                    NSLog(@"%s %d error: %@", __PRETTY_FUNCTION__, granted, error);
            }];
        
        UNNotificationAction *answerAction = [UNNotificationAction actionWithIdentifier:kSCPNotificationsAnswerActionIdentifier
                                                                                  title:answerTitle
                                                                                options:(UNNotificationActionOptionAuthenticationRequired | UNNotificationActionOptionForeground)];
        
        UNNotificationAction *declineAction = [UNNotificationAction actionWithIdentifier:kSCPNotificationsDeclineActionIdentifier
                                                                                   title:declineTitle
                                                                                 options:UNNotificationActionOptionDestructive];
        
        UNNotificationCategory *incomingCategory = [UNNotificationCategory categoryWithIdentifier:kSCPNotificationsIncomingCategoryIdentifier
                                                                                          actions:@[answerAction, declineAction]
                                                                                intentIdentifiers:@[]
                                                                                          options:0];
        
        UNNotificationAction *acceptVideoAction = [UNNotificationAction actionWithIdentifier:kSCPNotificationsAcceptVideoActionIdentifier
                                                                                  title:acceptVideoTitle
                                                                                options:(UNNotificationActionOptionAuthenticationRequired | UNNotificationActionOptionForeground)];
        
        UNNotificationAction *declineVideoAction = [UNNotificationAction actionWithIdentifier:kSCPNotificationsDeclineVideoActionIdentifier
                                                                                   title:declineVideoTitle
                                                                                 options:UNNotificationActionOptionDestructive];
        
        UNNotificationCategory *videoRequestCategory = [UNNotificationCategory categoryWithIdentifier:kSCPNotificationsVideoRequestCategoryIdentifier
                                                                                              actions:@[acceptVideoAction, declineVideoAction]
                                                                                    intentIdentifiers:@[]
                                                                                              options:0];
        
        UNNotificationAction *endAction = [UNNotificationAction actionWithIdentifier:kSCPNotificationsEndActionIdentifier
                                                                                  title:endTitle
                                                                                options:UNNotificationActionOptionDestructive];
        
        UNNotificationCategory *endCategory = [UNNotificationCategory categoryWithIdentifier:kSCPNotificationsEndCategoryIdentifier
                                                                                          actions:@[endAction]
                                                                                intentIdentifiers:@[]
                                                                                          options:0];

        NSSet *categoriesSet = [NSSet setWithArray:@[incomingCategory, videoRequestCategory, endCategory]];
        
        [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:categoriesSet];
        [[UNUserNotificationCenter currentNotificationCenter] setDelegate:self];
    }
    else {
        
        UIMutableUserNotificationAction *answerAction = [UIMutableUserNotificationAction new];
        answerAction.identifier = kSCPNotificationsAnswerActionIdentifier;
        answerAction.title = answerTitle;
        answerAction.activationMode = UIUserNotificationActivationModeForeground;
        answerAction.destructive = NO;
        answerAction.authenticationRequired = YES;// Ignored with UIUserNotificationActivationModeForeground mode (YES is implied)
        
        UIMutableUserNotificationAction *declineAction = [UIMutableUserNotificationAction new];
        declineAction.identifier = kSCPNotificationsDeclineActionIdentifier;
        declineAction.title = declineTitle;
        declineAction.activationMode = UIUserNotificationActivationModeBackground;
        declineAction.destructive = YES;
        declineAction.authenticationRequired = NO;
        
        UIMutableUserNotificationCategory *actionsCategory = [UIMutableUserNotificationCategory new];
        actionsCategory.identifier = kSCPNotificationsIncomingCategoryIdentifier;
        [actionsCategory setActions:@[answerAction, declineAction] forContext:UIUserNotificationActionContextDefault];
        [actionsCategory setActions:@[answerAction, declineAction] forContext:UIUserNotificationActionContextMinimal];
        
        UIMutableUserNotificationAction *acceptVideoAction = [UIMutableUserNotificationAction new];
        answerAction.identifier = kSCPNotificationsAcceptVideoActionIdentifier;
        answerAction.title = acceptVideoTitle;
        answerAction.activationMode = UIUserNotificationActivationModeForeground;
        answerAction.destructive = NO;
        answerAction.authenticationRequired = YES;
        
        UIMutableUserNotificationAction *declineVideoAction = [UIMutableUserNotificationAction new];
        declineAction.identifier = kSCPNotificationsDeclineVideoActionIdentifier;
        declineAction.title = declineVideoTitle;
        declineAction.activationMode = UIUserNotificationActivationModeBackground;
        declineAction.destructive = YES;
        declineAction.authenticationRequired = NO;
        
        UIMutableUserNotificationCategory *videoRequestCategory = [UIMutableUserNotificationCategory new];
        actionsCategory.identifier = kSCPNotificationsVideoRequestCategoryIdentifier;
        [actionsCategory setActions:@[acceptVideoAction, declineVideoAction] forContext:UIUserNotificationActionContextDefault];
        [actionsCategory setActions:@[acceptVideoAction, declineVideoAction] forContext:UIUserNotificationActionContextMinimal];
        
        UIMutableUserNotificationAction *endAction = [UIMutableUserNotificationAction new];
        endAction.identifier = kSCPNotificationsEndActionIdentifier;
        endAction.title = endTitle;
        endAction.activationMode = UIUserNotificationActivationModeBackground;
        endAction.destructive = YES;
        endAction.authenticationRequired = NO;
        
        UIMutableUserNotificationCategory *endCategory = [UIMutableUserNotificationCategory new];
        endCategory.identifier = kSCPNotificationsEndCategoryIdentifier;
        [endCategory setActions:@[endAction] forContext:UIUserNotificationActionContextDefault];
        [endCategory setActions:@[endAction] forContext:UIUserNotificationActionContextMinimal];
        
        UIUserNotificationSettings *currentNotifSettings = [UIApplication sharedApplication].currentUserNotificationSettings;
        
        UIUserNotificationType notifTypes = currentNotifSettings.types;
        
        if (notifTypes == 0)
            notifTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        
        NSSet *cat = [NSSet setWithObjects:actionsCategory, videoRequestCategory, endCategory,nil];
        
        UIUserNotificationSettings *newNotifSettings = [UIUserNotificationSettings settingsForTypes:notifTypes
                                                                                         categories:cat];
        
        [[UIApplication sharedApplication] registerUserNotificationSettings:newNotifSettings];
    }
}

- (BOOL)hasPermission {
    if (_userNotificationsSupported) {
        __block BOOL bGranted = NO;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            bGranted = (settings.authorizationStatus == UNAuthorizationStatusAuthorized);
            dispatch_semaphore_signal(semaphore);
        }];
        
        dispatch_time_t timeout = dispatch_time(NULL, 10*1e9); // 10 seconds in nanoseconds
        dispatch_semaphore_wait(semaphore, timeout);
        
        return bGranted;
    } else {
        // return YES if any types are set
        // NOTE: we might consider returning YES only if ALL requested types are set
        return ([UIApplication sharedApplication].currentUserNotificationSettings.types != 0);
    }
}

#pragma mark - Public

-(void)cancelAllNotifications {
    
    if(_userNotificationsSupported) {
        
        [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
    }
    else {
        
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }

    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
}

-(void)cancelNotificationForCall:(SCPCall *)call {
    
    if(!call)
        return;

    if(_userNotificationsSupported) {
        
        if(call.uniqueCallId) {

            [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[call.uniqueCallId]];
            [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[call.uniqueCallId]];
        }
        
        return;
    }

    if(call.incomingCallNotif) {
        
        [[UIApplication sharedApplication] cancelLocalNotification:call.incomingCallNotif];
        [call setIncomingCallNotif:nil];
    }

    if(call.isEnded && call.activeCallNotif) {
        
        [[UIApplication sharedApplication] cancelLocalNotification:call.activeCallNotif];
        [call setActiveCallNotif:nil];
    }
}

-(void)cancelMessageNotificationForChatObject:(ChatObject *)chatObject {
    
    // Only supported by the User Notifications framework
    
    if(!_userNotificationsSupported)
        return;
    
    if(!chatObject)
        return;
    
    [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[chatObject.msgId]];
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[chatObject.msgId]];
}

-(void)handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification {
    
    if(!notification)
        return;
    
    if(!notification.userInfo)
        return;
    
    if(![notification.userInfo objectForKey:kSCPNotificationUserInfoTypeKey])
        return;
    
    scsNotificationType notificationType = (scsNotificationType)[[notification.userInfo objectForKey:kSCPNotificationUserInfoTypeKey] integerValue];
    
    if(notificationType == kSCSNotificationTypeCall) {
        
        NSString *uniqueCallId  = [notification.userInfo objectForKey:@"identifier"];
        NSUUID *callUUID        = [[NSUUID alloc] initWithUUIDString:uniqueCallId];
        SCPCall *call           = [SPCallManager callWithUUID:callUUID];
        
        [self handleCallNotificationActionWithIdentifier:identifier
                                                 forCall:call];
        
    }
    else if(notificationType == kSCSNotificationTypeMessage) {
        
        NSString *contactName = [notification.userInfo objectForKey:@"identifier"];
        
        [self handleMessageNotificationActionForContactName:contactName];
    }
    
    // Delete the consumed notification
    [[UIApplication sharedApplication] cancelLocalNotification:notification];
}

-(void)presentVideoRequestNotificationForCall:(SCPCall *)call {
    
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;
    
    if(!call)
        return;
    
    NSString *displayName = [call getName];
    
    if (!displayName)
        displayName = NSLocalizedString(@"Anonymous", nil);
    
    [self scheduleNotificationWithTitle:NSLocalizedString(@"Video call request", nil)
                                   body:[NSString stringWithFormat: NSLocalizedString(@"%@ wants to switch to video call", nil), displayName]
                                   type:kSCSNotificationTypeCall
                             identifier:call.uniqueCallId
                       threadIdentifier:nil
                             attachment:nil
                               category:kSCPNotificationsVideoRequestCategoryIdentifier
                               ringtone:kSCPNotificationsDefaultSound];
}

-(void)presentIncomingCallNotificationForCall:(SCPCall *)call {

    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;
    
    if(!call)
        return;
    
    NSString *displayName = [call getName];
    NSString *displayNumber = [call displayNumber];
    
    if (!displayName)
        displayName = NSLocalizedString(@"Anonymous", nil);
    
    if (!displayNumber || [displayName isEqualToString:displayNumber])
        displayNumber = @"";

    const char * getRingtone(const char *p=NULL);
    const char * getEmergencyRingtone(void);
    
    NSString *ringtone =  [NSString stringWithFormat:@"%s.caf", call.isEmergency ? getEmergencyRingtone(): getRingtone()];

    id notification = [self scheduleNotificationWithTitle:NSLocalizedString(@"Incoming call", nil)
                                                     body:[NSString stringWithFormat: NSLocalizedString(@"%@ %@", nil), displayName, displayNumber]
                                                     type:kSCSNotificationTypeCall
                                               identifier:call.uniqueCallId
                                         threadIdentifier:nil
                                               attachment:nil
                                                 category:kSCPNotificationsIncomingCategoryIdentifier
                                                 ringtone:ringtone];
    
    if(notification)
       [call setIncomingCallNotif:(UILocalNotification *)notification];
}

-(void)presentMissedCallNotificationForCall:(SCPCall *)call {
    
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;
    
    if(!call)
        return;
    
    if(call.isAnswered)
        return;
    
    if(call.shouldNotAddMissedCall)
        return;

    if(call.iEnded == eCallUserLocal)
        return;

    if(!call.isIncoming)
        return;
    
    NSString *title = NSLocalizedString(@"Missed call", nil);
    // check user's preference for displaying caller name
    NSString *mn = (NSString *)[[SCPSettingsManager shared] valueForKey:@"szMessageNotifcations"];
    // if it's not OK to show caller's name, use the call bufMsg instead
    NSString *body = ([@"Notification only" isEqualToString:mn]) ? call.bufMsg : [call getName];
    // strip out any redundant title in body message
    if ([body hasPrefix:title])
        body = [[body substringFromIndex:title.length] stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    
    [self scheduleNotificationWithTitle:title
                                   body:body
                                   type:kSCSNotificationTypeCall
                             identifier:call.uniqueCallId
                       threadIdentifier:nil
                             attachment:nil
                               category:nil
                               ringtone:nil];
}

-(void)presentIncomingMessageNotificationForChatObject:(ChatObject *)chatObject {
    
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;
    
    if(!chatObject)
        return;
    
    __weak SCPNotificationsManager *weakManager = self;

    [[SCSContactsManager sharedManager] addressBookContactWithInfo:chatObject.contactName
                                                        completion:^(AddressBookContact *contact) {
                                                     
                                                         __strong SCPNotificationsManager *strongManager = weakManager;
                                                         
                                                         if(!strongManager)
                                                             return;
                                                         
                                                        NSString *displayName = (contact ? contact.fullName : nil);

                                                        if(!displayName)
                                                            displayName = chatObject.displayName;

                                                        if(!displayName || displayName.length < 1)
                                                            displayName = chatObject.contactName;
                                                        
                                                         [strongManager presentIncomingMessageNotificationForChatObject:chatObject
                                                                                                        withDisplayName:displayName];
                                                     }];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)())completionHandler {
    
    UNNotificationContent *content = response.notification.request.content;
    
    scsNotificationType notificationType = (scsNotificationType)[[content.userInfo objectForKey:kSCPNotificationUserInfoTypeKey] integerValue];
    
    if(notificationType == kSCSNotificationTypeCall) {

        NSString *uniqueCallId  = response.notification.request.identifier;
        NSUUID *callUUID        = [[NSUUID alloc] initWithUUIDString:uniqueCallId];
        SCPCall *call           = [SPCallManager callWithUUID:callUUID];

        [self handleCallNotificationActionWithIdentifier:response.actionIdentifier
                                                 forCall:call];

    }
    else if(notificationType == kSCSNotificationTypeMessage) {
        
        NSString *contactName = response.notification.request.content.threadIdentifier;
        
        [self handleMessageNotificationActionForContactName:contactName];
    }
    
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    // Defer any notification action when the app is at the foreground
    completionHandler(UNNotificationPresentationOptionNone);
}

@end
