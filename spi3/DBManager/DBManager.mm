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

#import "axolotl_glue.h"
#import "appRepository/AppRepository.h"
#include "interfaceApp/AppInterfaceImpl.h"

#import "DBManager.h"

#import "BurnTimer.h"
#import "ChatUtilities.h"
#import "DBManager+CallManager.h"
#import "DBManager+Encryption.h"
#import "DBManager+MessageReceiving.h"
#import "GroupChatManager.h"
#import "RecentObject.h"
#import "SCAttachment.h"
#import "SCFileManager.h"
#import "SCPCall.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCSChatSectionObject.h"
#import "SCSContactsManager.h"
#import "SCSEnums.h"
#import "SCSPLog_private.h"
#import "NSDictionaryExtras.h"
#import "SCSAvatarManager.h"

#import "CTMutex.h"
static CTMutex db_mutex;

using namespace zina;

static AppRepository *db = NULL;
static DBManager *dBManagerInstance = NULL;

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation DBManager
{    
    NSMutableDictionary *recents;
    
    NSMutableArray *burnTimers;
    NSTimer *nextBurnTimer;
    
    // HashTable of allSentMessages msgid,
    // used to fast find anychatobject by msgid
    // populated from ChatObject msgid setter
    
    NSMapTable *allSentMessages;
    
    NSMutableArray *sendingNow;
    
    int markAsReadLastMsgCount;
}

+(DBManager *)dBManagerInstance
{
    //we call this to offten and that is why we need initialize
    //when we really want to setup DB and we call it twice we have to
    //call [Switchboard doCmd:@":delay_reg=0"]; to stop delaying registrations
    return dBManagerInstance;
}

+(void) setup{
    DDLogDebug(@"%s", __FUNCTION__);
    
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        
        dBManagerInstance = [self new];
        dBManagerInstance->allSentMessages  = [NSMapTable new];
        dBManagerInstance->tmpRecvMessages  = [NSMapTable new];
        dBManagerInstance->sendingNow       = [NSMutableArray new];
        
        NSString *dbPath = [SCFileManager chatDbFileURL].relativePath;        
        AppRepository * getChatDb(const char *dbPath);        
        db = getChatDb(dbPath.UTF8String);        
        if (!db) {
            return;
        }
        
        bool areZinaDatabasesOpen(void);        
        if(areZinaDatabasesOpen()) {
            
            [Switchboard doCmd:@":delay_reg=0"];
            [Switchboard doCmd:@":reg" ];
        }
    
        [dBManagerInstance getDatabase];
        
        [[NSNotificationCenter defaultCenter] addObserver:dBManagerInstance
                                                 selector:@selector(callDidEnd:)
                                                     name:kSCPCallDidEndNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:dBManagerInstance
                                                 selector:@selector(engineStateDidChange:)
                                                     name:kSCPEngineStateDidChangeNotification
                                                   object:nil];
    });
}

-(void)getDatabase
{
    DDLogDebug(@"%s", __FUNCTION__);
    
    //The loadAllConversations is setting flag when it
    // is ready to accept messages  and sip-engine knows
    //when it can pass messages to DB
    [self loadAllConversations];
    
    // Set up group callbacks only after we have loaded recents
    [GroupChatManager sharedInstance];

    [self syncReadStatuses];//TODO move this to lazy
}

//sync unread messages from userdefaults vs DB
-(void) syncReadStatuses
{
    DDLogDebug(@"%s", __FUNCTION__);
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"unreadMessages"])
    {
        NSMutableDictionary *syncedUnreadMessages = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *unreadMessages = [[[NSUserDefaults standardUserDefaults] objectForKey:@"unreadMessages"] mutableCopy];
        for (NSString *contactName in unreadMessages.allKeys) {
            NSMutableArray *messages = [unreadMessages objectForKey:contactName];
            
            NSMutableArray *syncedMessages = [[NSMutableArray alloc] init];
            for (NSString *msgID in messages) {
                // if message is error message or msgID is wrong by some reason
                if (msgID.length < 4) {
                    continue;
                }
                BOOL exist = db->existEvent(contactName.UTF8String, msgID.UTF8String);
                
                if (exist) {
                    [syncedMessages addObject:msgID];
                }
            }
            if (syncedMessages.count > 0 && contactName)
            {
                [syncedUnreadMessages setObject:syncedMessages forKey:contactName];
            }
        }
        
        [ChatUtilities utilitiesInstance].unreadMessages = syncedUnreadMessages;
        [[NSUserDefaults standardUserDefaults] setObject:syncedUnreadMessages forKey:@"unreadMessages"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetBadgeNumberNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSResetAppBadgeNumberNotification object:self];
    }
    
}

-(void) engineStateDidChange:(NSNotification *) notification //redo v3
{
    DDLogDebug(@"%s", __FUNCTION__);
    
    static BOOL online = NO;
    online =  [Switchboard allAccountsOnline];
    if(!online)return ;
    
    static int processing = NO;
    if(processing)return;
    processing = YES;
    
    static BOOL didStartRetryReceivedMessages = NO;
    
    if(!didStartRetryReceivedMessages &&
       [[UIApplication sharedApplication] applicationState]==UIApplicationStateActive){
        
        didStartRetryReceivedMessages = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
            app->retryReceivedMessages();
            
        });
    }
    
    NSArray *b = [[ChatUtilities utilitiesInstance].stackedOfflineBurns allValues] ;
    NSArray *r = [[ChatUtilities utilitiesInstance].stackedOfflineReads allValues] ;
    if(!b.count && !r.count){
        processing = NO;
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(b.count > 0)
        {
            
            for (ChatObject *thisChatObject in b) {
                //thisChatObject can be outdated
                //loading fresh one
                ChatObject *m = [self loadEventWithMessageID:thisChatObject.msgId andContactName:thisChatObject.contactName];
                if(!m)continue;
                
                int64_t v = [[DBManager dBManagerInstance] sendForceBurnFromTheSameThread:m];
                if(v){
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [[ChatUtilities utilitiesInstance].stackedOfflineBurns removeObjectForKey:m.msgId];
                    });
                    m.isStoredAfterDeletion = 0;
                    [[DBManager dBManagerInstance] removeChatMessage:m postNotification:YES];
                }
                
                if(!online)break;
                
            }
        }
        
        if(online && r.count > 0)
        {
            
            for (ChatObject *thisChatObject in r) {
                ChatObject *m = [self loadEventWithMessageID:thisChatObject.msgId andContactName:thisChatObject.contactName];
                if(!m || m.isGroupChatObject == 1)continue;
                
                int64_t v = [[DBManager dBManagerInstance] sendReadNotificationFromTheSameThread:m];
                
                if(v){
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [[ChatUtilities utilitiesInstance].stackedOfflineReads removeObjectForKey:m.msgId];
                    });
                    
                    m.mustSendRead = NO;
                    [self saveMessage:m];
                }
                
                if(!online)break;
                
            }
            
        }
        processing = NO;
    });
    
}

#pragma mark message saving
/**
 * Save Message
 **/
-(int) saveMessage:(ChatObject*)thisChatObject
{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__, thisChatObject.displayName, thisChatObject.senderDisplayName);
    
    if(!thisChatObject)
        return 0;
    
    if (thisChatObject.attachment) {
        [thisChatObject saveAttachment];
    }
    return [self saveEvent:thisChatObject];
}


#pragma mark remove messages

-(void) removeChatWithContact:(RecentObject*) recentToRemove //ok
{
    DDLogDebug(@"%s", __FUNCTION__);
    
    if (recentToRemove.isGroupRecent)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[GroupChatManager sharedInstance] leaveGroup:recentToRemove.contactName];
        });
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [AvatarManager deleteAvatarForConversation:recentToRemove];
    });
    
    db_mutex.lock();
    
    [[ChatUtilities utilitiesInstance] removeBadgesForConversation:recentToRemove];
    
    [recents removeObjectForKey:recentToRemove.contactName];
    db_mutex.unLock();
    
    [self deleteConversationWithName:recentToRemove.contactName];
    
    if ([[ChatUtilities utilitiesInstance].selectedRecentObject isEqual:recentToRemove])
    {
        [ChatUtilities utilitiesInstance].selectedRecentObject = nil;
    }
}


/**
 * Remove single message from chatview by msgId
 **/
-(void) removeChatMessage:(ChatObject*) chatObjectToRemove postNotification:(BOOL) post
{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__, chatObjectToRemove.displayName, chatObjectToRemove.senderDisplayName);

    
    [self deleteEvent:chatObjectToRemove postNotification:post];
}

//will not and must not search in DB
-(ChatObject*) getRecentlySentChatObjectByMessageIdentifier:(long long) messageIdentifier
{
    DDLogDebug(@"%s messageIdentifier: %lld", __FUNCTION__, messageIdentifier);
    
    if(!messageIdentifier)return nil;
    
    //from lib zina
    //The transport id is structured: bits 0..3 are status/type bits, bits 4..7 is a counter, bits 8..63 random data
    NSString *hashKey = [NSString stringWithFormat:@"%llu",messageIdentifier>>8];
    
    CTMutexAutoLock _a(db_mutex);
    //TODO remove from this list if we have >=200 back from the server
    return [allSentMessages objectForKey:hashKey];
    
}

-(void)markAsSendingChatObject:(ChatObject *)co mark:(BOOL)mark{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@ _ mark: %@",
              __FUNCTION__,co.displayName,co.senderDisplayName,(mark)?@"true":@"false");

    if(mark)[sendingNow addObject:co.msgId];
    else {
        if([sendingNow containsObject:co.msgId]){
            [sendingNow removeObject:co.msgId];
        }
    }
}

-(BOOL)isSendingNowChatObject:(ChatObject *)co{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,co.displayName,co.senderDisplayName);
    
    return [sendingNow containsObject:co.msgId];
}

-(void)addChatObjectToRecentlySent:(ChatObject *)co msgDeliveryId:(long long)msgDeliveryId{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@ _ msgDeliverId: %lld",
              __FUNCTION__,co.displayName,co.senderDisplayName,msgDeliveryId);

    if(!msgDeliveryId || co.isReceived)return;
    NSString *hashKey = [NSString stringWithFormat:@"%llu",msgDeliveryId>>8];
    
    CTMutexAutoLock _a(db_mutex);
    if (co && hashKey)
        [allSentMessages setObject:co forKey:hashKey];
}

-(void)removeFromRecentlySent:(ChatObject *)co{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,co.displayName,co.senderDisplayName);

    if(!co.messageIdentifier || co.isReceived)return;
    NSString *hashKey = [NSString stringWithFormat:@"%llu",co.messageIdentifier>>8];
    
    CTMutexAutoLock _a(db_mutex);
    [allSentMessages removeObjectForKey:hashKey];
    
}

-(BOOL) existEvent:(NSString *) msgID andContactName:(NSString *) contactName {
    DDLogDebug(@"%s contactName: %@",__FUNCTION__,contactName);

    RecentObject *r = [self getRecentByName:contactName];
    if(!r)return NO;
    CTMutexAutoLock _a(db_mutex);
    
    BOOL exist = db->existEvent(r.contactName.UTF8String, msgID.UTF8String);
    return exist;
    
}

-(ChatObject *) loadEventWithMessageID:(NSString *) msgID andContactName:(NSString *) contactName
{
    DDLogDebug(@"%s msgID: %@ _ contactName: %@",__FUNCTION__,msgID,contactName);

    RecentObject *recent = [self getRecentByName:contactName];
    
    if(!recent)
        return nil;
    
    if(!recent.contactName)
        return nil;
    
    std::string event;
    
    db_mutex.lock();
    db->loadEventWithMsgId(msgID.UTF8String, &event);
    db_mutex.unLock();
    
    if(event.length() < 1)
        return nil;
    
    // Use the canonical recent name to decrypt data
    //
    // For group messages the contactName argument is D01FC2E2-20E8-11E7-9B61-7FEC04C88F99
    // and the recent.contactName is d01fc2e2-20e8-11e7-9b61-7fec04c88f99@sip.silentcircle.net
    //
    // For 1-to-1 messages the contactName is equal to recent.contactName
    NSString *ns = [self decryptData:recent.contactName.UTF8String
                          dataFromDB:event];
    
    if(!ns)
        return nil;

    NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData
                                                             options:0
                                                               error:nil];
    
    return [self createChatObjectFromDictionary:JSONDict];
}


-(void) deleteConversationWithName:(NSString *) name
{
    DDLogDebug(@"%s name: %@",__FUNCTION__,name);

    NSMutableArray *messageList = [self loadAllEventsForContactName:name];
    for (ChatObject *chatObject in messageList)
        [self deleteEvent:chatObject postNotification:NO];
    
    CTMutexAutoLock _a(db_mutex);
    
    db->deleteEventName(name.UTF8String);
    db->deleteConversation(name.UTF8String);
    
}


-(int)saveEvent:(ChatObject *)thisChatObject
{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName);
    
    RecentObject *recentToUpdate = [self getOrCreateRecentObjectWithContactName:thisChatObject.contactName];
    
    if(!recentToUpdate)
    {
        DDLogError(@"%s saveEvent fail !recentToUpdate",__PRETTY_FUNCTION__);
        return SC_DB_ERR_CODE_OFFSET+2000;
        
    }
    BOOL bRecentDidChange = NO;
    
    if(thisChatObject.isReceived && thisChatObject.displayName && !thisChatObject.isGroupChatObject){
        if(![thisChatObject.displayName isEqualToString:recentToUpdate.displayName]){
            recentToUpdate.displayName = thisChatObject.displayName;
            bRecentDidChange = YES;
        }
    }
    
    if(thisChatObject.unixTimeStamp > recentToUpdate.unixTimeStamp || recentToUpdate.lastConversationObject == nil || recentToUpdate.lastConversationObject.unixTimeStamp<thisChatObject.unixTimeStamp){
        recentToUpdate.lastConversationObject = thisChatObject;
        recentToUpdate.unixTimeStamp = recentToUpdate.lastConversationObject.unixTimeStamp;
        bRecentDidChange =YES;
    }
    
    // update conversation with last message sent or received
    
    // first update conversation, then insertEvent, because of table constraint
    if(bRecentDidChange){
        [self saveRecentObject:recentToUpdate];
    }
    
    int ret = [self saveMessageWOupdatingRecent:thisChatObject];
    
    ChatObject* c = [self getRecentlySentChatObjectByMessageIdentifier:thisChatObject.messageIdentifier];
    if(c && (thisChatObject.messageStatus ==200 || thisChatObject.isRead)){
        [self removeFromRecentlySent:c];
    }
    else if(c && c!=thisChatObject){//we have no most recent object in DB and we have to replace
        [self removeFromRecentlySent:c];
        [self addChatObjectToRecentlySent:thisChatObject msgDeliveryId:c.messageIdentifier];
    }
    
    return ret;
    
}

-(int) saveRecentObject:(RecentObject*) thisRecent
{
    DDLogDebug(@"%s displayAlias: %@ ",__FUNCTION__,thisRecent.displayAlias);

    if (!thisRecent)
    {
        return 0;
    }
    NSError *writeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[thisRecent dictionaryRepresentation]
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    
    std::string str;
    encryptData(thisRecent.contactName.UTF8String, jsonString,str);
    
    CTMutexAutoLock _a(db_mutex);
    int ret = db->storeConversation(thisRecent.contactName.UTF8String, str);
    
    return ret? (SC_DB_ERR_CODE_OFFSET+ret) : 0;
    
}

-(int)saveMessageWOupdatingRecent:(ChatObject *)thisChatObject{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName);

    NSError *writeError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:thisChatObject.dictionary options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    std::string str;
    encryptData(thisChatObject.contactName.UTF8String, jsonString, str);
    
    int ret = 0;
    const char *e =NULL;
    
    {
        CTMutexAutoLock _a(db_mutex);
        
        ret = db->insertEvent(thisChatObject.contactName.UTF8String, thisChatObject.msgId.UTF8String, str);
        if(ret==SQLITE_DONE)ret = 0;
        
        if(ret){
            e = db->getLastError();
        }
    }
    if(ret){
        DDLogError(@"%s!!! ERROR_SP_DB: !!! db->insertEvent() fail code=%d [%s]",__PRETTY_FUNCTION__,ret, e);
    }
    return ret? (SC_DB_ERR_CODE_OFFSET+ret) : 0;
}
// TODO needs seperate ChatObject deleting and removing from DB
-(void) deleteEvent:(ChatObject*)thisChatObject postNotification:(BOOL) post
{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName);
    if (!thisChatObject)
        return;


    RecentObject *r = [self getRecentByName:thisChatObject.contactName];
    BOOL recentDidUpdate = NO;
    if(r && r.lastConversationObject && [r.lastConversationObject.msgId isEqualToString:thisChatObject.msgId])
    {
        r.lastConversationObject = nil;
        recentDidUpdate = YES;
    }
    
    if(thisChatObject.halfLoaded){//we need this because we want to clean attacment data
        ChatObject *o = [self loadEventWithMessageID:thisChatObject.msgId andContactName:thisChatObject.contactName];
        if(o)thisChatObject = o;
    }
    
    
    [self removeFromBurnTimersArray:thisChatObject];
    [self removeFromRecentlySent:thisChatObject];
    
    [[ChatUtilities utilitiesInstance] removeBadgeNumberForChatObject:thisChatObject];
    
    [thisChatObject deleteAttachment];
    if(thisChatObject.isStoredAfterDeletion || thisChatObject.mustSendRead){
        thisChatObject.messageText = @"";
        [self saveMessageWOupdatingRecent:thisChatObject];
        
    }
    
    else if (thisChatObject.contactName && thisChatObject.msgId)
    {
        CTMutexAutoLock _a(db_mutex);
        db->deleteEvent(thisChatObject.contactName.UTF8String, thisChatObject.msgId.UTF8String);
    }
    if (post && thisChatObject)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPRemoveMessageNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
    }
    
    if(recentDidUpdate && r)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:r}];
    }
}




#pragma mark burnTimer
/**
 * Launches nstimer when chatObject gets taken out of database
 * saves nstimers in utilities, for now not used
 * @param burnTime - burnTime of chatObject
 * @param thisChatObject - chatobject for which to launch timer
 * @param shouldRemove - should check if burntimer is in the past and delete chatObject
 **/
-(void) setOffBurnTimerForBurnTime:(long) burnTime andChatObject:(ChatObject*) thisChatObject checkForRemoveal:(BOOL) shouldRemove
{
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@ _ shouldRemove: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName,(shouldRemove)?@"true":@"false");

    if(!thisChatObject.burnTime){
        thisChatObject.burnTime = burnTime;
    }
    
    [self addToBurnTimersArray:thisChatObject shouldResetBurntimer:YES];
}


-(ChatObject *) createChatObjectFromDictionary:(NSDictionary *) JSONDict{
    DDLogDebug(@"%s",__FUNCTION__);

    return [self createChatObjectFromDictionary:JSONDict fastLoadOnly:NO];
    
}

-(ChatObject *) createChatObjectFromDictionary:(NSDictionary *) JSONDict fastLoadOnly:(BOOL)fastLoadOnly
{
    DDLogDebug(@"%s json.displayName: %@ _ json.contactName: %@",
              __FUNCTION__,JSONDict[@"displayName"],JSONDict[@"contactName"]);
    
    NSString *messagetext = fastLoadOnly? nil: [JSONDict objectForKey:@"messageText"];
    NSString *display_name = fastLoadOnly? nil: [JSONDict objectForKey:@"displayName"];
    NSString *contactName = [JSONDict objectForKey:@"contactName"];
    NSString *msgId = [JSONDict objectForKey:@"msgId"];
    NSString *isRead = [JSONDict objectForKey:@"isRead"];
    
    NSArray *preparedMessageData = [JSONDict objectForKey:@"preparedMessageData"];
    
    NSString *senderDisplayName = [JSONDict objectForKey:@"senderDisplayName"];
    
    ChatObject *thisChatObject;
    if([JSONDict objectForKey:@"isCall"])
    {
        
        thisChatObject = [[ChatObject alloc] initWithCall];
        
        if(!fastLoadOnly){
            
            NSArray *callsArray = [JSONDict valueForKey:@"calls"];
            int callState = [[JSONDict objectForKey:@"callState"] intValue];
            long callDuration = [[JSONDict objectForKey:@"callDuration"] longValue];
            int isIncomingCall = [[JSONDict objectForKey:@"isIncomingCall"] intValue];
            
            thisChatObject.isIncomingCall = isIncomingCall;
            thisChatObject.callState = callState;
            thisChatObject.callDuration = callDuration;
            
            if(callsArray)
                thisChatObject.calls = [callsArray mutableCopy];
            
            if(!messagetext)
            {
                thisChatObject.messageText = [[ChatUtilities utilitiesInstance] getCallInfoFromCallChatObject:thisChatObject];
            } else
            {
                thisChatObject.messageText = messagetext;
            }
        }
        
        
        int unixTimeStamp = [[JSONDict objectForKey:@"unixTimeStamp"] intValue];
        int burnTime = [[JSONDict objectForKey:@"burnTime"] intValue];
        long long unixReadTimeStamp = [[JSONDict objectForKey:@"unixReadTimeStamp"] longLongValue];
        
        thisChatObject.contactName = contactName;
        thisChatObject.msgId = msgId;
        thisChatObject.isRead = [isRead intValue];
        thisChatObject.unixTimeStamp = unixTimeStamp;
        thisChatObject.burnTime = burnTime;
        thisChatObject.unixReadTimeStamp = unixReadTimeStamp;
        
        thisChatObject.isCall = YES;
        
    } else
    {
        
        NSString *isReceived = [JSONDict objectForKey:@"isReceived"];
        
        
        long long messageStatus = [[JSONDict objectForKey:@"messageStatus"] longLongValue];
        long long messageIdentifier = [[JSONDict objectForKey:@"messageIdentifier"] longLongValue];
        int unixTimeStamp = [[JSONDict objectForKey:@"unixTimeStamp"] intValue];
        int unixDeliveryTimeStamp = [[JSONDict objectForKey:@"unixDeliveryTimeStamp"] intValue];
        
        long long unixReadTimeStamp = [[JSONDict objectForKey:@"unixReadTimeStamp"] longLongValue];
        int burnTime = [[JSONDict objectForKey:@"burnTime"] intValue];
        
        int hasFailedAttachment = [[JSONDict objectForKey:@"hasFailedAttachment"] intValue];
        int isgroupChatObject = [[JSONDict objectForKey:@"isGroupChatObject"] intValue];
        int isInvitationChatObject = [[JSONDict objectForKey:@"isInvitationChatObject"] intValue];
        
        BOOL isSynced = [[JSONDict objectForKey:@"isSynced"] boolValue];
        
        NSString *errorString = [JSONDict objectForKey:@"errorString"];
       NSString *errorStringExistingMsg = [JSONDict objectForKey:@"errorStringExistingMsg"];
        
        NSString *grpId = [JSONDict objectForKey:@"grpId"];
        
        NSDictionary *locationDict =  fastLoadOnly ? nil :[JSONDict objectForKey:@"location"];
        
        //if there is no message status then probably and
        //the APP did exit and we have not deliver
        if([isReceived intValue] != 1 && messageStatus == 0){
            if(![sendingNow containsObject:msgId]){
                ChatObject *c = [self getRecentlySentChatObjectByMessageIdentifier:messageIdentifier];
                if(!c){//this means we are not sending the message out now and we will not get an update about state
                    messageStatus = -2;
                }
            }
        }
        
        
        CLLocation *location = nil;
        if(locationDict )
        {
            
            float altitude = [[locationDict objectForKey:@"altitude"] floatValue];
            float latitude = [[locationDict objectForKey:@"latitude"] floatValue];
            float longitude = [[locationDict objectForKey:@"longitude"] floatValue];
            float horizontalAccuracy = [[locationDict objectForKey:@"horizontalAccuracy"] floatValue];
            float verticalAccuracy = [[locationDict objectForKey:@"verticalAccuracy"] floatValue];
            
            CLLocationCoordinate2D coordinate;
            coordinate.latitude = latitude;
            coordinate.longitude = longitude;
            
            location = [[CLLocation alloc] initWithCoordinate:coordinate altitude:altitude horizontalAccuracy:horizontalAccuracy verticalAccuracy:verticalAccuracy timestamp:[NSDate dateWithTimeIntervalSince1970:unixTimeStamp]];
            
        }
        
        SCAttachment *attachment = nil;
        
        if(!fastLoadOnly){
            
            NSString *cloudLocator = [JSONDict objectForKey:@"cloudLocator"];
            NSString *cloudKey = [JSONDict objectForKey:@"cloudKey"];
            NSArray *segmentList = [JSONDict objectForKey:@"segmentList"];
            
            
            NSString *attachmentName = [JSONDict objectForKey:@"attachment"];
            if ([attachmentName length] > 0) {

                NSString *fn = [NSString stringWithFormat:@"/%@.sc", attachmentName];
                NSString *attachmentPath = [[SCFileManager chatDirectoryURL] URLByAppendingPathComponent:fn].path;
                
                // supporting backwards-compatibility for older attachments?
                NSDictionary *backwardsCompatibilityDict = nil;
                attachment = [SCAttachment attachmentFromFile:attachmentPath results:&backwardsCompatibilityDict];
                // EA: remove this when no longer needed
                if (!cloudLocator)
                    cloudLocator = [backwardsCompatibilityDict objectForKey:@"cloudLocator"];
                if (!cloudKey)
                    cloudKey = [backwardsCompatibilityDict objectForKey:@"cloudKey"];
                if (!segmentList)
                    segmentList = [backwardsCompatibilityDict objectForKey:@"segmentList"];
                
                attachment.cloudLocator = cloudLocator;
                attachment.cloudKey = cloudKey;
                attachment.segmentList = segmentList;
            }
        }
        
        thisChatObject = (attachment) ? [[ChatObject alloc] initWithAttachment:attachment]
        : [[ChatObject alloc] initWithText:messagetext];
        thisChatObject.contactName = contactName;
        thisChatObject.unixTimeStamp = unixTimeStamp;
        thisChatObject.unixReadTimeStamp = unixReadTimeStamp;
        thisChatObject.unixDeliveryTimeStamp = unixDeliveryTimeStamp;
        thisChatObject.isRead = [isRead intValue];
        thisChatObject.isReceived = [isReceived intValue];
        thisChatObject.messageText = attachment ? @"": messagetext;
        thisChatObject.msgId = msgId;
        thisChatObject.errorString = errorString;
        thisChatObject.errorStringExistingMsg = errorStringExistingMsg;
        thisChatObject.isSynced = isSynced;
        thisChatObject.messageStatus = messageStatus;
        thisChatObject.messageIdentifier = messageIdentifier;
        thisChatObject.burnTime = burnTime;
        thisChatObject.hasFailedAttachment = hasFailedAttachment;
        thisChatObject.displayName = display_name;
        thisChatObject.halfLoaded = fastLoadOnly;
        thisChatObject.preparedMessageData = [preparedMessageData mutableCopy];
        
        if (isgroupChatObject)
        {
            thisChatObject.isGroupChatObject = isgroupChatObject;
            thisChatObject.isInvitationChatObject = isInvitationChatObject;
            thisChatObject.senderDisplayName = senderDisplayName;
            thisChatObject.grpId = grpId;
        }
        
        id deliv = [JSONDict objectForKey:@"delivered"];
        if(deliv)thisChatObject.delivered = [deliv boolValue];
        
        int v = [[JSONDict objectForKey:@"mustSendRead"]intValue];
        if(v){
            thisChatObject.mustSendRead = YES;
        }
        
        NSString *sendersDevID = [JSONDict objectForKey:@"sendersDevID"];
        if(sendersDevID){
            thisChatObject.sendersDevID =  sendersDevID;
        }
        
        
        if(location)
        {
            thisChatObject.location = location;
        }
    }
    return thisChatObject;
}


#pragma mark DBManager_V3

/**
 * list of all usernames for conversations
 **/
-(void) loadAllConversations
{
    DDLogDebug(@"%s",__FUNCTION__);

    db_mutex.lock();
    recents = [NSMutableDictionary new];
    db_mutex.unLock();
    
    std::list<std::string>* conversationList =  db->listConversations();
    
    if(conversationList != NULL) {

        while (!conversationList->empty()) {
            
            std::string resultStr = conversationList->front();
            
            // make sure we use correct format for contactname keys
            // recents with different keys will be formatted to contactname@sip.silentcircle.net
            // duplicate recents will stay in db but will get replaced when assigning them to recents dictionary
            NSString *name = [NSString stringWithUTF8String:resultStr.c_str()];
            
            name = [[ChatUtilities utilitiesInstance] removePeerInfo:name
                                                           lowerCase:NO];
            
            name = [[ChatUtilities utilitiesInstance] addPeerInfo:name
                                                        lowerCase:NO];
            
            RecentObject *recent = [self loadConversationWithName:name];
            if (recent.contactName)
            {
                db_mutex.lock();
                recents[name] = recent;
                db_mutex.unLock();
            }
            
            conversationList->erase(conversationList->begin());
        }
    
        delete conversationList;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSDBManagerLoadedAllConversationsNotification
                                                            object:self];
        
        db_mutex.lock();
        NSArray *a = [recents.allKeys copy];
        db_mutex.unLock();
        
        [[SCSContactsManager sharedManager] updateSilentCircleHashCacheWithContactInfos:a];
    });
}

-(NSArray *)getRecents{
    DDLogDebug(@"%s",__FUNCTION__);
    
    CTMutexAutoLock _m(db_mutex);
    
    return [recents.allValues copy];
}

-(RecentObject *) loadConversationWithName:(NSString*) name
{
    DDLogDebug(@"%s name: %@",__FUNCTION__,name);

    std:: string data;
    
    db_mutex.lock();
    db->loadConversation(name.UTF8String, &data);
    db_mutex.unLock();
    
    NSString *ns = [self decryptData:name.UTF8String dataFromDB:data];
    if(!ns)
    {
        return nil;
    }
    NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
    
    NSString *contactName =  [JSONDict safeStringForKey:@"contactName"];
    NSString *displayName =  [JSONDict safeStringForKey:@"displayName"];
    NSString *displayAlias =  [JSONDict safeStringForKey:@"displayAlias"];
    NSString *displayOrganization = [JSONDict safeStringForKey:@"displayOrganization"];
    NSString *avatarUrl = [JSONDict safeStringForKey:@"avatarUrl"];
    int hasBurnBeenSet =  [JSONDict safeIntForKey:@"hasBurnBeenSet"];
    int isGroupRecent =  [JSONDict safeIntForKey:@"isGroupRecent"];
    int hasGroupAvatarBeenSetExplicitly =  [JSONDict safeIntForKey:@"hasGroupAvatarBeenSetExplicitly"];
    int hasGroupNameBeenSetExplicitly =  [JSONDict safeIntForKey:@"hasGroupNameBeenSetExplicitly"];
    
    int burnDelayDuration = [JSONDict safeIntForKey:@"burnDelayDuration"];
    int shareLocationTime = [JSONDict safeIntForKey:@"shareLocationTime"];
    
    long unixTimeStamp = [JSONDict safeUnsignedLongForKey:@"unixTimeStamp"];
    
    NSString *avatarDataString = [JSONDict safeStringForKey:@"avatarImageString"];
    
    RecentObject *thisRecent = [RecentObject new];    
    
    // we want the contactname key to be in format  contactname@sip.silentcircle.net
    // if the saved contactname is in different format clean it and add this format
    // FIX: duplicate conversations because some had sip: prefix and some didn't
    // e.g. sip:gosis@sip.silentcircle.net and gosis@sip.silentcircle.net were stored as two recentObjects but led to the same conversation
    contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO];
    contactName = [[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:NO];
    
    thisRecent.contactName = contactName;
    thisRecent.displayName = displayName;
    thisRecent.unixTimeStamp = unixTimeStamp;
    if(hasBurnBeenSet)
    {
        thisRecent.hasBurnBeenSet = hasBurnBeenSet;
    }
    if (displayAlias) {
        thisRecent.displayAlias = displayAlias;
    }
    
    if (displayOrganization) {
        thisRecent.displayOrganization = displayOrganization;
    }
    
    if (avatarUrl) {
        thisRecent.avatarUrl = avatarUrl;
    }
    
    if (isGroupRecent)
    {
        thisRecent.isGroupRecent = isGroupRecent;
        thisRecent.hasGroupAvatarBeenSetExplicitly = hasGroupAvatarBeenSetExplicitly;
        thisRecent.hasGroupNameBeenSetExplicitly = hasGroupNameBeenSetExplicitly;
    }
    thisRecent.burnDelayDuration = burnDelayDuration;
    thisRecent.shareLocationTime = shareLocationTime;

    //thisRecent.drEnabled = [[JSONDict objectForKey:@"drEnabled"] boolValue];
    //thisRecent.drOrganization = [JSONDict objectForKey:@"drOrganization"];
    //thisRecent.drTypeCode = (uint32_t)[[JSONDict objectForKey:@"drTypeCode"] unsignedLongValue];
    //thisRecent.drBlockCode = (uint32_t)[[JSONDict objectForKey:@"drBlockCode"] unsignedLongValue];
    return thisRecent;
    
}


-(NSMutableArray *) loadAllEventsForContactName:(NSString *)name{
    DDLogDebug(@"%s contactname: %@",__FUNCTION__,name);

    std:: list<std::string*> allEventsList;
    std::int32_t lastMessageNumber = 0;
    
    db_mutex.lock();
    db->loadEvents(name.UTF8String,-1, -1, -1, &allEventsList, &lastMessageNumber);
    db_mutex.unLock();
    
    NSMutableArray *messagesWithThisContact = [[NSMutableArray alloc] init];
    
    //NSMutableArray *callsWithThisContact = [[NSMutableArray alloc] init];
    // last taken chatobject
    // meant to replace conversation last object when last gets deleted
    
    while (!allEventsList.empty()) {
        std::string resultStr = *allEventsList.front();
        
        NSString *ns = [self decryptData:name.UTF8String dataFromDB:resultStr];
        
        NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
        
        ChatObject *thisChatObject = [self createChatObjectFromDictionary:JSONDict];
        [messagesWithThisContact addObject:thisChatObject];
        allEventsList.erase(allEventsList.begin());
    }
    
    return messagesWithThisContact;
}

-(NSMutableArray *) loadEventsForRecent:(RecentObject *)recent offset:(int)offset count:(int) count completionBlock:(void (^)(NSMutableArray *array, int lastMsgNumber)) completion
{
    DDLogDebug(@"%s Recent: %@",__FUNCTION__, recent);
    
    if(!recent)
        return nil;
    
    if(offset == 0)
        return nil;
    
    std:: list<std::string*> allEventsList;
    std::int32_t lastMessageNumber = 0;
    db_mutex.lock();
    
    db->loadEvents(recent.contactName.UTF8String, offset, count, -1, &allEventsList, &lastMessageNumber);
    db_mutex.unLock();
    
    NSMutableArray *messagesWithThisContact = [[NSMutableArray alloc] init];
    
    //NSMutableArray *callsWithThisContact = [[NSMutableArray alloc] init];
    // last taken chatobject
    // meant to replace conversation last object when last gets deleted
    
    while (!allEventsList.empty()) {
        std::string resultStr = *allEventsList.front();
        
        BOOL wasDeleted = NO;
        
        NSString *ns = [self decryptData:recent.contactName.UTF8String
                              dataFromDB:resultStr];
        
        NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
        
        ChatObject *thisChatObject = [self createChatObjectFromDictionary:JSONDict];
        
        // start burntimers or check to delete only chat messages in conversations with contactnames not with numbers
        // if burn time is in the past, delete message from db
        // else add message to burnTimers dictionary and perform remove chatobject selector after burnTime
        // also delete if this chatobject doesn't have message text or attachment
        if(thisChatObject.mustRemoveFromDB || (thisChatObject.messageText.length == 0 && !thisChatObject.attachment))
        {
            wasDeleted = YES;
            [self removeChatMessage:thisChatObject postNotification:NO];
            
        }
        if(!wasDeleted && !thisChatObject.isStoredAfterDeletion){
            [messagesWithThisContact addObject:thisChatObject];
        }
        
        allEventsList.erase(allEventsList.begin());
    }

    
    if(messagesWithThisContact.count > 0)
    {
        // Assigns unixTimeStamp of last conversationObject to RecentObject
        // Last conversation can be call or chat message
        RecentObject *recentObjectToUpdate = [self getOrCreateRecentObjectForReceivedMessage:recent.contactName                                                                              andDisplayName:recent.displayName isGroup:recent.isGroupRecent];
        recentObjectToUpdate.lastMsgNumber = lastMessageNumber - 1;
    }
    
    if(completion)
    {
        completion(messagesWithThisContact,lastMessageNumber - 1);
    }
    return messagesWithThisContact;
}


-(BOOL)existsRecentByName:(NSString *)name{
    DDLogDebug(@"%s contactname: %@",__FUNCTION__,name);
    
    return [self getRecentByName:name]?YES:NO;    
}


-(RecentObject*)getRecentByName:(NSString *)name{
    DDLogDebug(@"%s contactname: %@",__FUNCTION__,name);
    
    NSString *contactNameWithoutPeerInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:name lowerCase:YES];
    NSString *contactNameWithPeerInfo = [[ChatUtilities utilitiesInstance] addPeerInfo:name lowerCase:YES];
    RecentObject *thisRecent;
    
    CTMutexAutoLock _a(db_mutex);
    
    thisRecent = [recents objectForKey:contactNameWithoutPeerInfo];
    
    if(thisRecent)return thisRecent;
    
    if(!thisRecent)
    {
        thisRecent = [recents objectForKey:contactNameWithPeerInfo];
    }
    return thisRecent;
}

-(ChatObject *) getLastChatObjectForName:(NSString *) contactName{
    DDLogDebug(@"%s contactName: %@",__FUNCTION__,contactName);
    
    RecentObject *r = [self getRecentByName:contactName];
    if(!r)return nil;
    
    if(r.lastConversationObject)return r.lastConversationObject;
    /*
     To find actual last message we load last 20 messages and assume that the actual last message by creation time should be there
     
     There is no guarantee that the last loaded message is the actual last one that's why loading only one message is not enough
     */
    NSArray *lastMessagesArray = [self loadEventsForRecent:r
                                                    offset:-1
                                                     count:20
                                           completionBlock:nil];
    
    if (lastMessagesArray.count == 0)
    {
        return nil;
    }
    
    
    const long long usec_per_sec = 1000000;
    ChatObject *lastChatObject = nil;
    for (ChatObject * chatObject in lastMessagesArray)
    {
        if (!lastChatObject)
        {
            lastChatObject = chatObject;
        } else
        {
            long long tChatObject = (long long)chatObject.timeVal.tv_sec * usec_per_sec + (long long)chatObject.timeVal.tv_usec;
            long long tlastChatObject = (long long)lastChatObject.timeVal.tv_sec * usec_per_sec + (long long)lastChatObject.timeVal.tv_usec;
            if(tChatObject > tlastChatObject)
            {
                lastChatObject = chatObject;
            }
        }
    }
    r.lastConversationObject = lastChatObject;
    
    return r.lastConversationObject;
    
}

// TODO: Make this method accept a recent object instead of those three arguments
-(RecentObject *) getOrCreateRecentObjectForReceivedMessage:(NSString *) uuid andDisplayName:(NSString *) displayName isGroup:(BOOL) isGroup
{
    DDLogDebug(@"%s\n\tuuid: %@\n\tdisplayName: %@",__FUNCTION__, uuid, displayName);
    
    //TODO mutex
    NSString *contactNameWithoutPeerInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid lowerCase:YES];
    
    NSString *contactNameWithPeerInfo = [[ChatUtilities utilitiesInstance] addPeerInfo:contactNameWithoutPeerInfo lowerCase:YES];
    
    RecentObject *thisRecent;
    db_mutex.lock();
    
    thisRecent = [recents objectForKey:contactNameWithoutPeerInfo];
    
    if(!thisRecent)
    {
        thisRecent = [recents objectForKey:contactNameWithPeerInfo];
    }
    
    
    if (!thisRecent && contactNameWithPeerInfo)
    {
        thisRecent = [RecentObject new];
        
        thisRecent.contactName = contactNameWithPeerInfo;
        thisRecent.hasBurnBeenSet = 0;
        thisRecent.shareLocationTime = 0;
        thisRecent.burnDelayDuration = [ChatUtilities utilitiesInstance].kDefaultBurnTime;
        thisRecent.displayName = displayName;
        thisRecent.isGroupRecent = isGroup;
        [recents setObject:thisRecent forKey:contactNameWithPeerInfo];
        
        db_mutex.unLock();
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectCreatedNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey: thisRecent }];
        
        [self saveRecentObject:thisRecent];
        
    }
    else {
        db_mutex.unLock();
    }
    
    [[SCSContactsManager sharedManager] linkConversationWithContact:thisRecent];
    
    return thisRecent;
}

-(RecentObject *) getOrCreateRecentObjectWithContactName:(NSString *) contactName
{
    DDLogDebug(@"%s contactName: %@",__FUNCTION__,contactName);
    
    if (!contactName)
    {
        return nil;
    }
    //TODO mutex
    
    NSString *contactNameWithoutPeerInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:YES];
    
    NSString *contactNameWithPeerInfo = [[ChatUtilities utilitiesInstance] addPeerInfo:contactNameWithoutPeerInfo lowerCase:YES];
    RecentObject *thisRecent;
    
    db_mutex.lock();
    thisRecent = [recents objectForKey:contactNameWithoutPeerInfo];
    
    if(!thisRecent)
    {
        thisRecent = [recents objectForKey:contactNameWithPeerInfo];
    }
    db_mutex.unLock();
    
    if(!thisRecent.abContact)
        [[SCSContactsManager sharedManager] linkConversationWithContact:thisRecent];

    if (!thisRecent)
    {
        NSString *cn = nil;
        
        // if contactname is not an uuid
        if(![[ChatUtilities utilitiesInstance] isUUID:contactNameWithoutPeerInfo] && ![[ChatUtilities utilitiesInstance] isNumber:contactNameWithoutPeerInfo])
        {
            NSString *uuid = [[ChatUtilities utilitiesInstance] getUserNameFromAlias:contactNameWithoutPeerInfo];
            if(uuid.length > 0)
                cn = [[ChatUtilities utilitiesInstance] addPeerInfo:uuid lowerCase:YES];
        }
        
        if (!cn)
        {
            cn = contactNameWithPeerInfo;
        }
        
        db_mutex.lock();
        
        thisRecent = [recents objectForKey:cn];
        
        if(thisRecent){
            db_mutex.unLock();
            return thisRecent;
        }
        
        thisRecent = [RecentObject new];
        thisRecent.contactName = cn;
        thisRecent.isPartiallyLoaded = YES;
        thisRecent.hasBurnBeenSet = 0;
        thisRecent.unixTimeStamp = time(NULL);
        thisRecent.shareLocationTime = 0;
        thisRecent.burnDelayDuration = [ChatUtilities utilitiesInstance].kDefaultBurnTime;
        
        if (thisRecent.contactName)
            [recents setObject:thisRecent
                        forKey:thisRecent.contactName];
        
        db_mutex.unLock();
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : thisRecent }];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectCreatedNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : thisRecent }];
        
        [self saveRecentObject:thisRecent];
    }
    
    return thisRecent;
}

#pragma mark Burn handling v3

//must call this from background thread when app is in foreground
-(void) loadBackgroundTasks
{
    DDLogDebug(@"%s",__FUNCTION__);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // SP: Do we need the sleep() call here?
        DDLogDebug(@"-(DBManager) loadBackgroundTasks sleep(5)");
        sleep(5);
        [self checkDBAttachmentMigration];//we need this because we had a bug where we did not clean attachment from doc folder
        [self loadReloadBurnTimers];
        [self engineStateDidChange:nil];//try to resend burns and readreq
    });
}

-(void) checkDBAttachmentMigration{
    NSString *did_db_doc_sync = [[NSUserDefaults standardUserDefaults] objectForKey:@"did_db_doc_sync"];
    
    DDLogDebug(@"%s did_db_doc_sync: %@",__FUNCTION__, did_db_doc_sync);
    
    static int doMigration = !did_db_doc_sync || !did_db_doc_sync.longLongValue; //TODO get It From NSUserDefaults
    if(!doMigration)return;
    doMigration = 0;
    
    NSMutableArray *a = [self loadAttachmentFilenames];
    
    [self removeValidAttachmentsFromArray:a];
    
    NSError *e = nil;
    if(a.count){
        NSString *path = [SCFileManager chatDirectoryURL].relativePath;
        for(NSString *fileName in a){
            
            NSString *fp = [NSString stringWithFormat:@"%@/%@",path,fileName];
            
            [[NSFileManager defaultManager]removeItemAtPath:fp error:&e];
            if(e){
                DDLogError(@"%sfail to delete %@,error=%@",__PRETTY_FUNCTION__,fileName,e);
                break;
            }
            
        }
    }
    
    if(!e){
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%ld", time(NULL)] forKey:@"did_db_doc_sync"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    //if this is empty then everything is
    DDLogVerbose(@"%s (if this is empty then everything is good) array=%@",__PRETTY_FUNCTION__,a);    
}
-(NSMutableArray *)loadAttachmentFilenames{
    
    DDLogDebug(@"%s",__FUNCTION__);
    
    const int kMsgIDLen = 36;
    
    NSString *path = [SCFileManager chatDirectoryURL].relativePath;
    NSArray *directoryContent = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
    
    NSInteger c = [directoryContent count];
    if(c<1)return nil;
    
    NSMutableArray *cleanUpDocs = [[NSMutableArray alloc] initWithCapacity:c];
    
    for (int i = 0; i < c; i++)
    {
        NSString *ns = [directoryContent objectAtIndex:i];
        if([ns hasSuffix:@".sc"] && ns.length > kMsgIDLen+4 && ns.UTF8String[36]=='-'){
            
            //NSString *msgid = [NSString stringWithFormat:@"%.*s",kMsgIDLen, ns.UTF8String];
            //cleanUpDocs[msgid] = ns;
            [cleanUpDocs addObject:ns];
            //  NSLog(@"file %@", msgid);
        }
    }
    return cleanUpDocs;
}

-(void)removeValidAttachmentsFromArray:(NSMutableArray *)array{
    
    DDLogDebug(@"%s attachmentsArray.count: %lu",__FUNCTION__, (unsigned long)array.count);
    
    std::list<std::string>* conversationList =  db->listConversations();
    
    if(conversationList != NULL) {
        
        while (!conversationList->empty()) {
            
            std::string resultStr = conversationList->front();
            
            NSString *name = [NSString stringWithUTF8String:resultStr.c_str()];
            name = [[ChatUtilities utilitiesInstance] removePeerInfo:name lowerCase:NO];
            name = [[ChatUtilities utilitiesInstance] addPeerInfo:name lowerCase:NO];
            
            [self removeValidAttacmentsWithName:name array:array];
            
            conversationList->erase(conversationList->begin());
        }

        delete conversationList;
    }
}

-(void)loadReloadBurnTimers{
    
    DDLogDebug(@"%s",__FUNCTION__);
    
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
        return;
    
    @synchronized (self) {
        
        if(!burnTimers){
            
            burnTimers = [NSMutableArray new];
            
            std::list<std::string>* conversationList =  db->listConversations();
            
            if(conversationList != NULL) {
                
                while (!conversationList->empty()) {
                    
                    std::string resultStr = conversationList->front();
                    
                    NSString *name = [NSString stringWithUTF8String:resultStr.c_str()];
                    name = [[ChatUtilities utilitiesInstance] removePeerInfo:name lowerCase:NO];
                    name = [[ChatUtilities utilitiesInstance] addPeerInfo:name lowerCase:NO];
                    
                    [self loadConversationBackgroundTasksWithName:name];
                    
                    conversationList->erase(conversationList->begin());
                }
                
                delete conversationList;
            }
        }
        
        if (burnTimers.count > 0)
            [self setOffBurnTimerForBurnArrayChatObject];
    }
}

-(void) loadConversationBackgroundTasksWithName:(NSString*) name
{
    DDLogDebug(@"%s",__FUNCTION__);
    
    [self loadEventBackgroundTaskForContactName:name offset:-1 count:-1];
}

-(void) loadEventBackgroundTaskForContactName:(NSString *)name offset:(int)offset count:(int) count
{
    DDLogDebug(@"%s name: %@",__FUNCTION__,name);
    
    if(offset == 0)
        return;
    
    
    std:: list<std::string*> allEventsList;
    std::int32_t lastMessageNumber = 0;
    
    db_mutex.lock();
    db->loadEvents(name.UTF8String, offset, count, -1, &allEventsList, &lastMessageNumber);
    db_mutex.unLock();
    
    while (!allEventsList.empty()) {
        std::string resultStr = *allEventsList.front();
        
        BOOL wasDeleted = NO;
        
        NSString *ns = [self decryptData:name.UTF8String dataFromDB:resultStr];
        
        NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
        
        ChatObject *thisChatObject = [self createChatObjectFromDictionary:JSONDict fastLoadOnly:YES];
        id storedAfterDeletion = [JSONDict objectForKey:@"isStoredAfterDeletion"];
        
        if(storedAfterDeletion){
            int storedStatus = [storedAfterDeletion intValue];
            thisChatObject.isStoredAfterDeletion = storedStatus;
        }
        
        // start burntimers or check to delete only chat messages in conversations with contactnames not with numbers
        if (![[ChatUtilities utilitiesInstance] isNumber:thisChatObject.contactName]) {
            
            // if burn time is in the past, delete message from db
            // else add add message to burntimers array
            if(thisChatObject.mustRemoveFromDB)
            {
                wasDeleted = YES;
                //do not delete here if we have to send read rec or burn req
                [self removeChatMessage:thisChatObject postNotification:NO];
                
            } else
            {
                if (thisChatObject.isRead)
                {
                    [self addToBurnTimersArray:thisChatObject shouldResetBurntimer:NO];
                }
            }
        }
        
        
        // if chatobject wasn't deleted add it to chathistory
        if(!wasDeleted)
        {
            
            if(storedAfterDeletion)
            {
                
                if(thisChatObject.isStoredAfterDeletion == 1 && ![[ChatUtilities utilitiesInstance].stackedOfflineBurns  objectForKey:thisChatObject.msgId])
                {
                    if (thisChatObject && thisChatObject.msgId)
                        [[ChatUtilities utilitiesInstance].stackedOfflineBurns setObject:thisChatObject forKey:thisChatObject.msgId];
                }
            }
            if(thisChatObject.mustSendRead){
                if(![[ChatUtilities utilitiesInstance].stackedOfflineReads  objectForKey:thisChatObject.msgId]){
                    if (thisChatObject && thisChatObject.msgId)
                        [[ChatUtilities utilitiesInstance].stackedOfflineReads setObject:thisChatObject forKey:thisChatObject.msgId];
                }
            }
        }
        allEventsList.erase(allEventsList.begin());
    }
}

-(void) removeValidAttacmentsWithName:(NSString *)name array:(NSMutableArray*)array
{
    DDLogDebug(@"%s name: %@ array.count: %lul",__FUNCTION__,name, (unsigned long)array.count);
    
    std:: list<std::string*> allEventsList;
    std::int32_t lastMessageNumber = 0;
    
    db->loadEvents(name.UTF8String, -1, -1, -1, &allEventsList, &lastMessageNumber);
    
    while (!allEventsList.empty()) {
        std::string resultStr = *allEventsList.front();
        
        NSString *ns = [self decryptData:name.UTF8String dataFromDB:resultStr];
        
        NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
        
        NSString *str = [JSONDict objectForKey:@"attachment"];
        if(str){
            NSString *ns = [str stringByAppendingString:@".sc"];
            if([array containsObject:ns]){
                //--  NSLog(@"remove valid attachment%@",ns);
                [array removeObject:ns];
            }
        }
        allEventsList.erase(allEventsList.begin());
    }
}




-(void) setOffBurnTimerForBurnArrayChatObject {
    
    DDLogDebug(@"%s",__FUNCTION__);
    
    @synchronized (self) {
        if (burnTimers.count <= 0) {
            
            [nextBurnTimer invalidate];
            nextBurnTimer = nil;
            return;
        }
        
        BurnTimer *lastBurnTimer = (BurnTimer *)burnTimers.lastObject;
        
        if(!lastBurnTimer)return;
        
        if(lastBurnTimer.burnNow  || (lastBurnTimer.burnTime > 0 && lastBurnTimer.burnStartTimeStamp)) {
            
            long long unixBurnTime = lastBurnTimer.burnStartTimeStamp;
            long long burnTime = unixBurnTime + lastBurnTimer.burnTime;
            long long difference = [[NSDate dateWithTimeIntervalSince1970:burnTime] timeIntervalSinceNow];
            
            if (difference < 0 || lastBurnTimer.burnNow)
                difference = 1;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [nextBurnTimer invalidate];
                //TODO fix: do not start timer if we are in background
                nextBurnTimer = [NSTimer scheduledTimerWithTimeInterval:difference target:self selector:@selector(burnTimerTick:) userInfo:lastBurnTimer repeats:NO];
                [[NSRunLoop currentRunLoop] addTimer:nextBurnTimer forMode:NSRunLoopCommonModes];
            });
            
        }
    }
}

//TODO when add to this list create different object like {msgid, timetoburn} and do not store all chatobject
-(void) addToBurnTimersArray:(ChatObject *) thisChatObject shouldResetBurntimer:(BOOL) reset {
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@ _ reset: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName,(reset)?@"true":@"false");

    @synchronized (self) {
        BurnTimer *burnTimer = [BurnTimer new];
        burnTimer.burnNow           = thisChatObject.burnNow;
        
        // for group messages use creation time and for normal messages use read time
        burnTimer.burnStartTimeStamp     = thisChatObject.isGroupChatObject?thisChatObject.unixCreationTimeStamp:thisChatObject.unixReadTimeStamp;
        burnTimer.msgId             = thisChatObject.msgId;
        burnTimer.burnTime          = thisChatObject.burnTime;
        burnTimer.contactName       = thisChatObject.contactName;
        
        if(thisChatObject.burnNow)
            thisChatObject.burnTime = 3;
        
        if (burnTimers.count <= 0)
            [burnTimers addObject:burnTimer];
        else {
            
            long long thisCOBT =  thisChatObject.burnTime + thisChatObject.unixReadTimeStamp;
            int bt = (int)burnTimers.count;
            int jump = (bt + 1) / 2 ;
            int  npos = jump;
            
            while(1){
                if(npos<0)
                    npos =0 ;
                
                if(npos >= bt)
                    npos = bt-1;
                
                if(!jump)
                    break;
                
                BurnTimer* prev =  npos > 0 ?(BurnTimer *)burnTimers[npos-1] : (BurnTimer *)burnTimers[0];
                BurnTimer* next = (BurnTimer *)burnTimers[npos];
                
                long long p = prev.burnStartTimeStamp + prev.burnTime;
                long long n = next.burnStartTimeStamp + next.burnTime;
                if (n ==thisCOBT  || (p >=thisCOBT &&  thisCOBT>=n)){
                    [burnTimers insertObject:burnTimer atIndex:npos];
                    break;
                }
                
                if(npos + 1>= bt && thisCOBT<=n){
                    [burnTimers insertObject:burnTimer atIndex:bt];
                    break;
                }
                
                if(npos < 2 && p <= thisCOBT){
                    [burnTimers insertObject:burnTimer atIndex:0];
                    break;
                }
                
                jump=(jump+1)/2;
                
                if (p  < thisCOBT){
                    npos-=jump;
                }
                else if (n  > thisCOBT){
                    npos+=jump;
                }
            }
        }
        
        if (reset) {
            
            BurnTimer *lastBurnTimer = (BurnTimer *)burnTimers.lastObject;
            
            if ([lastBurnTimer.msgId isEqualToString:burnTimer.msgId])
                [self setOffBurnTimerForBurnArrayChatObject];
        }
    }
}

-(void)burnTimerTick:(NSTimer*) timer{
    BurnTimer *thisBurnTimer = (BurnTimer*) timer.userInfo;
    ChatObject *thisChatObject = [self loadEventWithMessageID:thisBurnTimer.msgId andContactName:thisBurnTimer.contactName];
    [self deleteEvent:thisChatObject postNotification:YES];
}

-(void) removeFromBurnTimersArray:(ChatObject *) thisChatObject {
    DDLogDebug(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__,thisChatObject.displayName,thisChatObject.senderDisplayName);

    @synchronized (self) {
        BurnTimer *burnTimerToRemove = nil;
        
        // if passed chatobject, find it and remove it, if passed nil remove the last one
        if ([thisChatObject isKindOfClass:[ChatObject class]]) {
            
            for (int i = (int)burnTimers.count; i > 0; i --) {
                
                BurnTimer *storedBurnTimer = (BurnTimer *)burnTimers[i - 1];
                
                if ([storedBurnTimer.msgId isEqualToString:thisChatObject.msgId]) {
                    
                    burnTimerToRemove = storedBurnTimer;
                    break;
                }
            }
        }
        else
            burnTimerToRemove = (BurnTimer *)burnTimers.lastObject;
        
        
        if(burnTimerToRemove)
            [burnTimers removeObject:burnTimerToRemove];
        
        // after removing set off timer for the next last object
        [self setOffBurnTimerForBurnArrayChatObject];
    }
}

-(void)deleteMessagesBeforeBurnTime:(int)burnTime uuid:(NSString *)uuid
{
    __block NSString *blockUUID = uuid;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        blockUUID = [[ChatUtilities utilitiesInstance] addPeerInfo:blockUUID lowerCase:YES];
        NSMutableArray *messages = [[DBManager dBManagerInstance] loadAllEventsForContactName:blockUUID];
        
        //If the burn timer is reduced, group messages with older creation time than newly set burn time are immediately deleted
        for (ChatObject *chatObject in messages)
        {
            if (!chatObject.isInvitationChatObject)
            {
                long long burnStartTimeStamp = chatObject.isGroupChatObject?chatObject.unixCreationTimeStamp:chatObject.unixReadTimeStamp;
                long long timeSinceMessageCreation = time(NULL) - burnStartTimeStamp;
                if (timeSinceMessageCreation > burnTime)
                {
                    [self deleteEvent:chatObject postNotification:YES];
                } else
                {
                    if (burnTime < chatObject.burnTime)
                    {
                        chatObject.burnTime = burnTime;
                        [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:chatObject}];
                        [[DBManager dBManagerInstance] saveMessage:chatObject];
                    }
                }
            }
        }
    });
}

-(void) markMessagesAsReadForConversation:(RecentObject *) recent
{
    __block RecentObject * blockRecent = recent;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        [[DBManager dBManagerInstance] loadEventsForRecent:blockRecent
                                                    offset:markAsReadLastMsgCount
                                                     count:50
                                           completionBlock:^(NSMutableArray *array, int lastMsgNumber) {
            for (ChatObject *chatObject in array)
            {
                if (chatObject.isReceived == 1 && chatObject.isGroupChatObject != 1 && chatObject.isRead != 1)
                {
                    chatObject.isRead = 1;
                    [self setOffBurnTimerForBurnTime:chatObject.burnTime andChatObject:chatObject checkForRemoveal:NO];
                    [self sendReadNotification:chatObject];
                    [self saveMessage:chatObject];
                }
            }
            markAsReadLastMsgCount = lastMsgNumber;
            [self markMessagesAsReadForConversation:blockRecent];
        }];
    });
}

@end
