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
#define kReceivedMessageStatusCode 200

#import <AddressBook/AddressBook.h>
#import <AudioToolbox/AudioServices.h>

#include "JsonStrings.h"
#include "storage/sqlite/SQLiteStoreConv.h"
#include "Constants.h"
#include "interfaceApp/AppInterfaceImpl.h"

#import "DBManager+MessageReceiving.h"
#import "DBManager+PreparedMessageData.h"
#import "GroupChatManager+Members.h"
#import "GroupChatManager+Messages.h"
#import "ChatUtilities.h"
#import "ChatManager.h"
#import "Constants.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCSAudioManager.h"
#import "SCSChatSectionObject.h"
#import "SCSContactsManager.h"
#import "UserService.h"
#import "NSDictionaryExtras.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

NSDictionary *dictFromCString(const std::string& str){
    
   if(str.length() < 1)
       return nil;
   
   NSString *ns = [NSString stringWithUTF8String:str.c_str()];
   NSData *data = [ns dataUsingEncoding:NSUTF8StringEncoding];
    
   return [NSJSONSerialization JSONObjectWithData:data
                                          options:kNilOptions
                                            error:nil];
}

void notifyCallback(int32_t notifyAction, const std::string& actionInformation, const std::string& devId) {

    DDLogInfo(@"%s notifyAction: %d actionInformation: %s devId: %s", __PRETTY_FUNCTION__, notifyAction, actionInformation.c_str(), devId.c_str());

    if(notifyAction == zina::AppInterface::DEVICE_SCAN) {

        __block NSString *user      = [NSString stringWithUTF8String:actionInformation.c_str()];
        __block NSString *deviceId  = [NSString stringWithUTF8String:devId.c_str()];
    
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            [Switchboard rescanDevicesForUserWithUUID:user];

            NSArray *deviceIds = [deviceId componentsSeparatedByString:@";"];
            
            [DBManager resendLastMessageForUUID:user
                                      deviceIds:deviceIds];
        });
    }
}

int32_t receiveAxoMsg(const std::string& messageDescriptor, const std::string& attachmentDescriptor, const std::string& messageAttributes){
   
    NSDictionary *messageDict   = dictFromCString(messageDescriptor);
    NSDictionary *attributeDict = dictFromCString(messageAttributes);
    NSDictionary *attachmentDict= dictFromCString(attachmentDescriptor);

    if([[DBManager dBManagerInstance] shouldIgnoreIncomingMessageAsDuplicateUsingMessageDict:messageDict
                                                                               attributeDict:attributeDict
                                                                              attachmentDict:attachmentDict])
        return 0;
    
    DDLogInfo(@"%s\nMessage: %@\nAttributes: %@\nAttachment: %@", __FUNCTION__, messageDict, attributeDict, attachmentDict);

    int ret = [[DBManager dBManagerInstance] storeMessageDict:messageDict
                                                attributeDict:attributeDict
                                               attachmentDict:attachmentDict];
    
    if(ret != zina::OK)
        return ret;
    
    return [[DBManager dBManagerInstance] receiveMessageDict:messageDict];
}

void stateAxoMsg(int64_t messageIdentfier, int32_t statusCode, const std::string& stateInformation){

    DDLogInfo(@"%s messageIdentfier: %lld\nstatusCode: %d\nstateInformation: %s",
              __FUNCTION__,messageIdentfier, statusCode, stateInformation.c_str());
    
    if(messageIdentfier == 0 && statusCode < -2 && stateInformation.length() > 0)
    {
       
        const char* sendEngMsg(void *pEng, const char *p);
        const char *showErrors = sendEngMsg(NULL,"cfg.iShowAxoErrorMessages");
       
        if(showErrors && showErrors[0]=='0')return;
       
        NSString *stateInfo = [NSString stringWithUTF8String:stateInformation.c_str()];
        if(!stateInfo)return;
       
        NSData *data = [stateInfo dataUsingEncoding:NSUTF8StringEncoding];
        if(!data)return;
        NSDictionary *errorDict = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:nil];
        
        NSDictionary *errorDetails = [errorDict objectForKey:@"details"];
        
        if(errorDetails)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {

                NSString *name = [errorDetails objectForKey:@"name"];
                NSString *msgId = [errorDetails objectForKey:@"msgId"];
                NSNumber *code = [errorDetails objectForKey:@"errorCode"];

                NSString *errorString = stateInfo;
                NSString *errMsg = NSLocalizedString(@"Decryption failed", nil);
                
                if(code) {
                   
                    NSString *zinaError = NSLocalizedString([[NSString alloc] initWithUTF8String:CTAxoInterfaceBase::getErrorMsg(code.intValue)], nil);

                    if(zinaError)
                        errMsg = [errMsg stringByAppendingString:[NSString stringWithFormat:@"\nError: %@", zinaError]];
                }

                zina::SQLiteStoreConv* store = zina::SQLiteStoreConv::getStore();
                
#ifdef DEBUG
                // If this is a DEBUG build
                // and the error code is a SQLite error
                // then also log the error by calling
                // the store->getLastError() function.
                if(code.intValue == zina::DATABASE_ERROR) {
                    
                    NSString *sqliteLastError = nil;
                    
                    const char *lastErrorStr = store->getLastError();
                    
                    if(lastErrorStr != NULL)
                        sqliteLastError = [NSString stringWithUTF8String:store->getLastError()];
                    
                    if(sqliteLastError)
                        errorString = [errorString stringByAppendingString:[NSString stringWithFormat:@"\n---\n%@", sqliteLastError]];
                }
#endif
                
               if(msgId && msgId.length > 0)
               {
                  {
                      std::list<StringUnique> traceRecords;
                      store->loadMsgTrace("",msgId.UTF8String ,"",traceRecords);//will log data
                  }
                  
                  if([[DBManager dBManagerInstance] existEvent:msgId andContactName:name])
                  {
                      name = [[ChatUtilities utilitiesInstance] addPeerInfo:name lowerCase:YES];
                      ChatObject *co = [[DBManager dBManagerInstance] loadEventWithMessageID:msgId andContactName:name];
                      if (!co)
                          return;
                      co = [[DBManager dBManagerInstance] updateMessageStatusForChatObject:co userData:errorDetails attribs:@{@"cmd":@"failed"}];

                      if(co.errorStringExistingMsg && co.errorStringExistingMsg.length > 0)return; //do not update and save twice
                      co.errorStringExistingMsg = stateInfo;
                      [[DBManager dBManagerInstance] saveMessage:co];
                      NSError *error = [NSError errorWithDomain:ChatObjectUpdatedNotification code:code.intValue userInfo:errorDict];
                      [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification
                                                                         object:[DBManager dBManagerInstance]
                                                                       userInfo:@{kSCPErrorDictionaryKey:error, kSCPChatObjectDictionaryKey:co}];
                     return;
                  }
               }
               

               
                ChatObject *thisChatObject = [[ChatObject alloc] init];
                thisChatObject.contactName = name;
                thisChatObject.msgId = msgId;
                thisChatObject.errorString = errorString;
                thisChatObject.isReceived = 1;
                thisChatObject.messageText = errMsg;
                
                // set error message as sent so it wouldn't send read states
                thisChatObject.isRead = 0;
                [thisChatObject takeTimeStamp];
#if HAS_DATA_RETENTION
                thisChatObject.drEnabled = ([Switchboard doesUserRetainDataType:kDRType_Message_Metadata] || [Switchboard doesUserRetainDataType:kDRType_Message_PlainText]);
#endif // HAS_DATA_RETENTION
                // dont add badges for error messages
                //[[ChatUtilities utilitiesInstance] addBadgeNumberWithChatObject:thisChatObject];
                [[DBManager dBManagerInstance] saveMessage:thisChatObject];

//                if (thisChatObject.drEnabled)
//                    [Switchboard retainMessage:thisChatObject];

                [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification object:[DBManager dBManagerInstance] userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
            });
        }
        
        return;
    }
    // if negative or 0 not sent out
    // 200 sent, ignore everything
    // 404 user doesnt exist
    // it's possible to receive status before message is sent
   
   NSString *sc = [NSString stringWithFormat:@"%d",statusCode];
   NSString *mi = [NSString stringWithFormat:@"%lld",messageIdentfier];
   
   ChatObject *chatObjectToChange = [[DBManager dBManagerInstance] getRecentlySentChatObjectByMessageIdentifier:messageIdentfier];
   if(!chatObjectToChange){
      
      NSString *existingMessageDeliveryStatus = [[DBManager dBManagerInstance].cachedMessageStatuses objectForKey:mi];
      
      if(existingMessageDeliveryStatus && existingMessageDeliveryStatus.longLongValue!=200)
      {
          if (sc && mi)
              [[DBManager dBManagerInstance].cachedMessageStatuses setObject:sc forKey:mi];
      }
   }
   else if(chatObjectToChange.messageStatus != kReceivedMessageStatusCode)
   {
      if(!chatObjectToChange.isRead){
         //get correct msg from DB
         ChatObject *c = [[DBManager dBManagerInstance] loadEventWithMessageID:chatObjectToChange.msgId andContactName:[[ChatUtilities utilitiesInstance] addPeerInfo:chatObjectToChange.contactName lowerCase:YES]];
         if(c){
            chatObjectToChange = c;
         }
      }
      
      if(!chatObjectToChange.didPlaySentSound && (statusCode==200 || statusCode==202)
         && chatObjectToChange.messageStatus!=202 && chatObjectToChange.messageStatus!=200){
         chatObjectToChange.didPlaySentSound = YES;
         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
             [SPAudioManager playSound:@"sent"
                                ofType:@"aiff"
                               vibrate:NO];
         });
      }
      if(chatObjectToChange.messageStatus != statusCode && chatObjectToChange.messageStatus!=200){
         //if we have 200 ignore other codes, if we have more eaqual than 200 ignore all error messages
         if((chatObjectToChange.messageStatus == 202 && statusCode == 200) ||
            (chatObjectToChange.messageStatus < 200 && statusCode >= 200) ||
            (chatObjectToChange.messageStatus > 202 && (statusCode == 202 || statusCode == 200)) ||
            (chatObjectToChange.messageStatus == 0 && statusCode != 0))
         {
            chatObjectToChange.iSendingNow = 0;
            chatObjectToChange.messageStatus = statusCode;
            [[DBManager dBManagerInstance] saveMessage:chatObjectToChange];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (chatObjectToChange)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:[DBManager dBManagerInstance] userInfo:@{kSCPChatObjectDictionaryKey:chatObjectToChange}];
                }
            });
         }
      }
   }
}

// FIXME: Construct the strings using the JSON API and also provide a type
// (zina::MSG_CMD for single chats or zina:GROUP_MSG_CMD for group chats)
static int64_t sendForceBurn(ChatObject *thisChatObject, int mySelf){

      
      NSString *ownUN = [[ChatUtilities utilitiesInstance] getOwnUserName];

      NSString *msgID = thisChatObject.msgId;
      NSString *userName = [[ChatUtilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:YES] ;
      
    DDLogInfo(@"%s ownUN: %@ _ msgId: %@ _ peerUser: %@",__FUNCTION__, ownUN, msgID, userName);

      char buf[1024];
      
      snprintf(buf, sizeof(buf)-1,
               "{"
               "\"version\": 1,"
               "\"recipient\": \"%s\","
            //   "\"deviceId\": 1,"
               "\"msgId\":\"%s\","
               "\"message\":\"\""
               "}"
               ,mySelf ? ownUN.UTF8String : userName.UTF8String
               ,msgID.UTF8String
               );
      
      char bufAttribs[512];
      
      if(!mySelf){
         
         snprintf(bufAttribs, sizeof(bufAttribs)-1,
                  "{"
                  "\"cmd\":\"bn\","
                  "\"rr_time\": \"%s\""
                  "}"
                  ,[[ChatUtilities utilitiesInstance]getISO8601Timestamp].UTF8String
                  );
         //2015-10-21T17:23:12+03:00
      }
      else{
         snprintf(bufAttribs, sizeof(bufAttribs)-1,
                  "{"
                  "\"cmd\":\"bn\","
                  "\"syc\":\"bn\","
                  "\"or\": \"%s\""
                  "}"
                  ,userName.UTF8String
                  );
      }
      int64_t result = CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(buf, mySelf, false, NULL, bufAttribs);
       
 
   return result;
}
/*
 attributeJson.put("syc", "rr");
 attributeJson.put("or", MessageUtils.getConversationId(msg));
 attributeJson.put("rr_time", ConversationActivity.ISO8601.format(new Date()));
 */


// FIXME: Construct the strings using the JSON API and also provide a type
// (zina::MSG_CMD for single chats or zina:GROUP_MSG_CMD for group chats)
static int64_t sendReadNotification(ChatObject *thisChatObject, int mySelf){
   
   NSString *ownUN = [[ChatUtilities utilitiesInstance] getOwnUserName];
   
   NSString *msgID = thisChatObject.msgId;
   NSString *userName = [[ChatUtilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:YES] ;
    
   DDLogInfo(@"%s ownUN: %@ _ msgId: %@ _ peerUser: %@",__FUNCTION__, ownUN, msgID, userName);
    
   char buf[1024];
   char bufAttribs[512];
   
   snprintf(buf, sizeof(buf)-1,
            "{"
            "\"version\": 1,"
            "\"recipient\": \"%s\","
            //   "\"deviceId\": 1,"
            "\"msgId\":\"%s\","
            "\"message\":\"\""
            "}"
            ,mySelf ? ownUN.UTF8String : userName.UTF8String
            ,msgID.UTF8String
            );
    
// TODO: add data retention 'rt' flag to attributes when appropriate
   if(!mySelf){
      
      snprintf(bufAttribs, sizeof(bufAttribs)-1,
               "{"
               "\"cmd\":\"rr\","
               "\"rr_time\": \"%s\""
               "}"
               ,[[ChatUtilities utilitiesInstance]getISO8601Timestamp].UTF8String //TODO fix this ,get from chatObject
               );
   }
   else{
      snprintf(bufAttribs, sizeof(bufAttribs)-1,
               "{"
               "\"cmd\":\"rr\","
               "\"syc\":\"rr\","
               "\"or\": \"%s\","
                "\"rr_time\": \"%s\""
               "}"
               ,userName.UTF8String
               ,[[ChatUtilities utilitiesInstance]getISO8601Timestamp].UTF8String//TODO fix this ,get from chatObject
               //msg could stay in quvue
               );
   }
   //TODOGO Add to sentchatobjects maptable
   return CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(buf,mySelf, false, NULL, bufAttribs);
}




@implementation DBManager (MessageReceiving)

+(ChatObject *) getLastSentChatObjectForUUID:(NSString *) uuid {

    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:uuid];

    if(!recent)
        return nil;
    
    return [self getLastSentChatObjectForRecent:recent];
}

+(ChatObject *) getLastSentChatObjectForRecent:(RecentObject *)recentObject {
    
    NSMutableArray *thisUsersChatHistory = [[DBManager dBManagerInstance] loadEventsForRecent:recentObject
                                                                                       offset:-1
                                                                                        count:10
                                                                              completionBlock:nil];
    
    long now = time(NULL);
    
    if(thisUsersChatHistory)
    {
        for (int i = 0 ; i<thisUsersChatHistory.count; i++)
        {
            ChatObject *thisChatObject = (ChatObject *) thisUsersChatHistory[i];
            if(thisChatObject.isReceived != 1 && !thisChatObject.isCall && !thisChatObject.isInvitationChatObject && !thisChatObject.isSynced &&
               (now < thisChatObject.unixTimeStamp + 60))
            {
                return thisChatObject;
            }
        }
    }
    return nil;
}

-(long)getTimeStamp:(NSDictionary*) attributeDict  key:(NSString *)key{
   id ts = [attributeDict objectForKey:key];
   
   long longTs=0;
   
   if(ts) {
      
      // Newer implementation: supporting Zulu time
      BOOL isString = [ts isKindOfClass:[NSString class]];
      
      // Older backward compatibility support for unix timestamp
      BOOL isNumber = [ts isKindOfClass:[NSNumber class]];
      
      if(isString) {
         
         NSString *zuluTimestamp = [attributeDict objectForKey:key];
         
         if(zuluTimestamp && zuluTimestamp.length>11) {
            longTs = [[ChatUtilities utilitiesInstance] getUnixTimeFromISO8601:zuluTimestamp];
         }
         
      } else if(isNumber) {
         
         NSNumber *unixTimestamp = [attributeDict objectForKey:key];
         
         if(unixTimestamp)
            longTs = unixTimestamp.longValue;
         
      } else {
         // ...or else something is terribly wrong
         NSLog(@"Malformed rr_time value");
      }
   }
    
    return longTs;
}

-(int) receiveMessageDict:(NSDictionary*) userData{
   
   NSString *msgId = [userData objectForKey:@"msgId"];
   NSString *contactName = [userData objectForKey:@"sender"];
    
    DDLogInfo(@"%s userData: %@",__FUNCTION__, userData);
    
   if(msgId.length<1 || contactName.length<1)return 0;   
   
   ChatObject * thisChatObject = (ChatObject *)[tmpRecvMessages objectForKey:msgId];
   
   if(!thisChatObject)return zina::OK;
   [tmpRecvMessages removeObjectForKey:msgId];
#if HAS_DATA_RETENTION
   thisChatObject.drEnabled = ([Switchboard doesUserRetainDataType:kDRType_Message_Metadata]
                               || [Switchboard doesUserRetainDataType:kDRType_Message_PlainText]);
#endif // HAS_DATA_RETENTION
   if(thisChatObject.tmpIsNewMsg){
      
     // BOOL tmpDownloadTOC = thisChatObject.tmpDownloadTOC;
      BOOL tmpAddBadge = thisChatObject.tmpAddBadge;
      
       dispatch_async(dispatch_get_main_queue(), ^(void) {
         if(!thisChatObject.isSynced){
             // GO - for group chat we can set this message can be set to be read when saving
            if(tmpAddBadge && thisChatObject.isRead != 1){
               [[ChatUtilities utilitiesInstance] addBadgeNumberWithChatObject:thisChatObject];
            }
            [self showMsgNotif:thisChatObject];
         }
           [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification object:[DBManager dBManagerInstance] userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
      });
   }
   
   if(thisChatObject.tmpAddToBurn || thisChatObject.isGroupChatObject)
   {
      //TODO fix: do not start timer if we are in background
      [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:YES];
   }

   
   
   if(thisChatObject.tmpPostStateDidChange){
      dispatch_async(dispatch_get_main_queue(), ^(void) {
          [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:[DBManager dBManagerInstance] userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
      });
   }
   
   if(thisChatObject.tmpRemBadge){
      dispatch_async(dispatch_get_main_queue(), ^(void) {
         [[ChatUtilities utilitiesInstance] removeBadgeNumberForChatObject:thisChatObject];
      });
   }
   

   [thisChatObject cleanTmpFlags];
#ifdef DEBUG
   if([thisChatObject.messageText isEqualToString:@"Md5 a"]){
      unsigned int calcMD5(const char *p, int iLen, int n);
      unsigned int code=calcMD5("abcd",4,5*20000000);
      NSLog(@"md5 a code %d",code);
   }
   dispatch_async(dispatch_get_main_queue(), ^(void) {
      
      if([thisChatObject.messageText isEqualToString:@"Nobeidzies"]){
         void crashAfter5sec();
         crashAfter5sec();
      }
      if([thisChatObject.messageText isEqualToString:@"Exitapp 0"]){
         exit(0);
      }
      if([thisChatObject.messageText isEqualToString:@"Divide by 0"]){
         int z = thisChatObject.messageText.length/0;
         thisChatObject.messageStatus = z;
      }
      if([thisChatObject.messageText isEqualToString:@"Assert x"]){
         assert(0);
      }
      
      if([thisChatObject.messageText isEqualToString:@"Md5 b"]){
         unsigned int calcMD5(const char *p, int iLen, int n);
         unsigned int code=calcMD5("abcd",4,5*20000000);
         NSLog(@"md5 b code %d",code);
      }
      
   });
#endif
   
   return zina::OK;
}

/**
 Check for duplicate messages and ignore them.

 @discussion We don't care about command messages 
 (command messages don't generate notifications)
 and generally we want them to go through in order
 to update the state of the chat message (e.g. set
 the status to Read etc).
 We only check for identical messages when the
 incoming message contains either a text message or an attachment.
 
 @param messageDict The message dictionary from message descriptor of the Axo callback
 @param attributeDict The attribute dictionary from message attributes descriptor of the Axo callback
 @param attachmentDict The attachment dictionary from the attachment descriptior of the Axo callback
 @return YES if the incoming message should be ignored, NO otherwise
 */
- (BOOL)shouldIgnoreIncomingMessageAsDuplicateUsingMessageDict:(NSDictionary *)messageDict
                                                 attributeDict:(NSDictionary *)attributeDict
                                                attachmentDict:(NSDictionary *)attachmentDict {

    if(!messageDict)
        return NO;
    
    NSString *msgId = [messageDict objectForKey:@"msgId"];

    if(!msgId)
        return NO;
    
    NSString *messageText = [messageDict objectForKey:@"message"];
    NSString *contactName = [messageDict objectForKey:@"sender"];
    NSString *grpId = [attributeDict objectForKey:@"grpId"];

    // We could be checking by using the "type" key of messageDict to
    // distinguish between normal message types and command message types
    // but it turns out that for the single chat case, we are sending the
    // commands as normal message types (look at functions sendForceBurn()
    // and sendReadNotification()) -> we don't provide a type so Zina
    // defaults to MSG_NORMAL (ReceiveMessage.cpp line 199).
    // Those functions need to be fixed.
    //
    // So instead of checking the "type" key, we are looking
    // if the message contains text or an attachment.
    // Definitely not the most elegant check.
    if(messageText.length > 0 || attachmentDict) {
        
        return [self existEvent:msgId
                 andContactName:(grpId ? grpId : contactName)];
    }
    
    return NO;
}

// save burn notice timers in chatobject
//-(void) receiveMessageAsJsonString:(NSNotification*) info{
-(int) storeMessageDict:(NSDictionary*) userData attributeDict:(NSDictionary *)attributeDict attachmentDict:(NSDictionary *)attachmentDict{
   
    // Ignore ping commands
    if(attributeDict && [attributeDict objectForKey:@"cmd"]) {
        
        if([[attributeDict objectForKey:@"cmd"] isEqualToString:@"ping"])
            return 0;
    }

    NSString *messageText = [userData objectForKey:@"message"];
    NSString *contactName = [userData objectForKey:@"sender"];
    NSString *msgId = [userData objectForKey:@"msgId"];
    NSString *display_name = [userData objectForKey:@"display_name"];
    
    NSString *grpId = [attributeDict objectForKey:@"grpId"];
    
    DDLogInfo(@"%s sender: %@ _ msgId: %@ grpId: %@ _ display_name: %@",
              __FUNCTION__, contactName, msgId, grpId, display_name);
    
    // if stackedBurns contains this msgID remove the ID from array and return
    if([[ChatUtilities utilitiesInstance].stackedBurns containsObject:msgId])//TODO make it NSMapTable
    {
        [[ChatUtilities utilitiesInstance].stackedBurns removeObject:msgId];
        [[NSUserDefaults standardUserDefaults] setObject:[ChatUtilities utilitiesInstance].stackedBurns forKey:@"stackedBurns"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return zina::OK;
    }
    
    int burnDelayTime = 0;
    CLLocation *location;
    
    BOOL isSync = NO;
    
    NSString *syc = [attributeDict objectForKey:@"syc"];
    // NSString *contactName = [attributesData objectForKey:@"sender"];
    if([syc isEqualToString:@"om"]){
        NSString *destination = [attributeDict objectForKey:@"or"];
        contactName = destination;
        isSync = YES;
    }
    
    if ([[[ChatUtilities utilitiesInstance] getOwnUserName] isEqualToString:contactName])
    {
        isSync = YES;
    }
   
    if(isSync){
       NSString *dpn =  [attributeDict objectForKey:@"dpn"];
      
       if(dpn && dpn.length > 1)display_name = dpn;
    }

#if HAS_DATA_RETENTION
    NSNumber *drStatus = [attributeDict objectForKey:[NSString stringWithUTF8String:zina::DR_STATUS_BITS]];
    BOOL messageHasDR = ( (drStatus) && ([drStatus intValue] != 0) );
#endif // HAS_DATA_RETENTION

	if ( (messageText.length < 1) && (!attachmentDict) )
    {
       if(syc && syc.length > 0){
          NSString *destination = [attributeDict objectForKey:@"or"];
          if(!destination)return 0;
          contactName = destination;
       }
       
        ChatObject *thisChatObject = [[DBManager dBManagerInstance] loadEventWithMessageID:msgId
                                                                            andContactName:[[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES]];

        NSString *cmd = [attributeDict objectForKey:@"cmd"];

        if([cmd isEqualToString:@"bn"] ||
           (syc && [syc isEqualToString:@"bn"] )){
            
            [[self class] removeMessages:@[ msgId ]
                        fromRecentWithID:contactName];
            
            if (thisChatObject && msgId)
                [tmpRecvMessages setObject:thisChatObject
                                    forKey:msgId];

            return zina::OK;
        }
        
#if HAS_DATA_RETENTION
        if ([kDR_Policy_Errors objectForKey:cmd] != nil) {
            // this message failed to deliver due to recipient's data retention policies
            long ts = [self getTimeStamp:attributeDict key:@"cmd_time"];
            if (!ts)
                ts = time(NULL);
            // update message to 'Failed' and set detailed error string
            thisChatObject.unixTimeStamp = ts;
            thisChatObject.messageStatus = -1; // Failed
            int r =[self saveMessage:thisChatObject];
            thisChatObject.tmpPostStateDidChange = YES;
            if (thisChatObject && msgId)
                [tmpRecvMessages setObject:thisChatObject forKey:msgId];

            // add another chat object which is a permanent error message
            ChatObject *errChatObject = [[ChatObject alloc] init];
            errChatObject.contactName = thisChatObject.contactName;
            // generate unique msgid for this error
            uuid_string_t msgid;
            errChatObject.msgId = [NSString stringWithFormat:@"%s",CTAxoInterfaceBase::generateMsgID(messageText.UTF8String, msgid, sizeof(msgid))];

            errChatObject.isReceived = 1;
            errChatObject.messageStatus = -1;
            if ([@"errdecf" isEqualToString:cmd])
                errChatObject.messageText = NSLocalizedString(@"Decryption failed", nil);
            else
                errChatObject.messageText = NSLocalizedString(@"Policy Error", nil);
            errChatObject.errorString = NSLocalizedString([kDR_Policy_Errors objectForKey:cmd], nil);
            errChatObject.isRead = 0;
            [errChatObject takeTimeStamp];
            [self saveMessage:errChatObject];

            [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification object:[DBManager dBManagerInstance] userInfo:@{kSCPChatObjectDictionaryKey:errChatObject}];

            // send out a local notification that we have received a DR error
            [Switchboard.notificationsManager presentIncomingMessageNotificationForChatObject:errChatObject];

            return r==0 ? zina::OK: r;
        }
#endif // HAS_DATA_RETENTION
        
       //we can receive burn notify later
        if(!thisChatObject)
        {
           return zina::OK;
        }

     //   [tmpRecvMessages setObject:thisChatObject forKey:msgId];
       
        if(!syc && display_name && display_name.length>1){
            thisChatObject.displayName = display_name;
        }
        int ret = 0;
       
        if([cmd isEqualToString:@"dr"]){//delivery notice
           if(thisChatObject.delivered)return zina::OK;
           
           BOOL doSave = NO;
           long ts = [self getTimeStamp:attributeDict key:@"dr_time"];
           if(ts && !thisChatObject.unixDeliveryTimeStamp){
              thisChatObject.iSendingNow = 0;
              thisChatObject.unixDeliveryTimeStamp = ts;
              doSave = YES;
           }
           if(!thisChatObject.delivered || doSave){
               thisChatObject.delivered = YES;
               thisChatObject = [[DBManager dBManagerInstance] updateMessageStatusForChatObject:thisChatObject userData:userData attribs:attributeDict];
               ret = [self saveMessage:thisChatObject];
              
              thisChatObject.tmpPostStateDidChange = YES;
           }
        }
        else if([cmd isEqualToString:@"rr"] || (syc && [syc isEqualToString:@"rr"] )){//read notice
           
            if(syc && [syc isEqualToString:@"rr"])
                [Switchboard.notificationsManager cancelMessageNotificationForChatObject:thisChatObject];
            
           if(thisChatObject.isRead==1)return zina::OK;
            //
           //this is ok if this is syc msg
           thisChatObject.tmpRemBadge = YES;
          //  dispatch_async(dispatch_get_main_queue(), ^(void) {
            //   [[ChatUtilities utilitiesInstance] removeBadgeNumberForChatObject:thisChatObject];
            //});
           
           long ts = [self getTimeStamp:attributeDict key:@"rr_time"];
           if(ts){
              thisChatObject.unixReadTimeStamp = ts;
           }

            thisChatObject.iSendingNow = 0;
            thisChatObject.isRead = 1;
            thisChatObject.tmpAddToBurn = YES;

            thisChatObject.tmpPostStateDidChange = YES;
            thisChatObject.delivered =YES;// and this also means that it was really delivered
            thisChatObject = [[DBManager dBManagerInstance] updateMessageStatusForChatObject:thisChatObject userData:userData attribs:attributeDict];
            
            ret = [self saveMessage:thisChatObject];
        }
        if (thisChatObject && msgId)
            [tmpRecvMessages setObject:thisChatObject forKey:msgId];
        return ret==0 ? zina::OK: ret;
    }
    else // read received message attributes
    {
        // TODO add check for location attribs
        NSString *burnDelayTimeString = [attributeDict objectForKey:@"s"];
        /*
         "la":56.9507556
         "lo":24.1336798
         a - altitude
         h - horizontal accuracy
         v - vertical accuracy
         */
        NSString *longitude = [attributeDict objectForKey:@"lo"];
        NSString *latitude = [attributeDict objectForKey:@"la"];
        
        NSString *altitude = [attributeDict objectForKey:@"a"];
        NSString *horizontalAccuracy = [attributeDict objectForKey:@"h"];
        NSString *verticalAccuracy = [attributeDict objectForKey:@"v"];
        
        if(burnDelayTimeString)
        {
            burnDelayTime = [burnDelayTimeString intValue];
            
        }
        
        if(longitude > 0)
        {
            CLLocationCoordinate2D coordinate;
            coordinate.longitude = [longitude floatValue];
            coordinate.latitude = [latitude floatValue];
            location = [[CLLocation alloc] initWithCoordinate:coordinate altitude:[altitude floatValue] horizontalAccuracy:[horizontalAccuracy floatValue] verticalAccuracy:[verticalAccuracy floatValue] timestamp:[NSDate dateWithTimeIntervalSince1970:burnDelayTime]];
        } else
        {
            location = nil;
        }

    }
   
   // if object with this msgid doesnt exist, add it,
   // if it exists, find and replace it, post status update to change info to display for this message
   
   //if it exists should get it(from loadEventWithMessageID) and update ??
   BOOL msgIdExists = [[DBManager dBManagerInstance] existEvent:msgId andContactName:contactName];
   if(msgIdExists)return zina::OK;

   ChatObject *thisChatObject;
   
   if (attachmentDict != nil) {
      SCAttachment *attachment = [[SCAttachment alloc] init];
      attachment.cloudLocator = [attachmentDict objectForKey:@"cloud_url"];
      NSObject *cloudKey = [attachmentDict objectForKey:@"cloud_key"];
      // from iOS: cloudKey was already turned into a NSDictionary due to JSON serialization above
      // from Android: cloudKey is a string
      if ([cloudKey isKindOfClass:[NSDictionary class]]) {
         NSData *keyData = [NSJSONSerialization dataWithJSONObject:cloudKey options:kNilOptions error:nil];
         attachment.cloudKey = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];
      } else if ([cloudKey isKindOfClass:[NSString class]])
         attachment.cloudKey = (NSString *)cloudKey;
      
      thisChatObject = [[ChatObject alloc] initWithAttachmentFromNetwork:attachment];
   } else
      thisChatObject = [[ChatObject alloc] init];
   
   thisChatObject.tmpIsNewMsg = YES;
   
   thisChatObject.contactName = contactName;
   thisChatObject.isReceived = isSync ? 0 : 1;
   if(!thisChatObject.isAttachment){
      thisChatObject.messageText = messageText;
   }
   thisChatObject.isRead = isSync ? 0 : -1;//start burn timer
   thisChatObject.msgId = msgId;
   thisChatObject.isSynced = isSync;
   thisChatObject.burnTime = burnDelayTime;
    
   [thisChatObject takeTimeStamp];
    
    
    // check if this is group message
    if (grpId)
    {
        thisChatObject.grpId = [[ChatUtilities utilitiesInstance] addPeerInfo:grpId lowerCase:YES];
        
        thisChatObject.senderDisplayName = display_name;
        RecentObject *existingRecent = [[DBManager dBManagerInstance] getRecentByName:thisChatObject.grpId];
        if (existingRecent)
        {
            display_name = existingRecent.displayName;
        }
        thisChatObject.isGroupChatObject = 1;
        thisChatObject.unixTimeStamp = time(NULL);
        
        if ([GroupChatManager existsCachedReadStatusMsgId:thisChatObject.msgId])
        {
            thisChatObject.isRead = 1;
            thisChatObject.unixReadTimeStamp = [GroupChatManager getCachedReadTimeForMsgId:thisChatObject.msgId];
            [GroupChatManager removeCachedReadStatusMsgId:thisChatObject.msgId];
        }
    }
   
#if HAS_DATA_RETENTION
    thisChatObject.drEnabled = messageHasDR;

    if (messageHasDR) {
        
        // this is a data-rentention message, do we recognize this person?
        NSString *contactNameWithPeerInfo = [[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES];
        RecentObject *existingRecent = [[DBManager dBManagerInstance] getRecentByName:contactNameWithPeerInfo];
        
        if (!existingRecent) {
            
            [Switchboard.userResolver enqueueResolutionForUUID:contactName
                                                    completion:^(RecentObject *updatedRecent) {
                                                        
                                                        if(!updatedRecent)
                                                            return;
                                                        
                                                        [[ChatUtilities utilitiesInstance] setSelectedRecentObject:updatedRecent];
                                                    }];
        }
    }
#endif
    BOOL isGroup = thisChatObject.isGroupChatObject;
    
    [[DBManager dBManagerInstance] getOrCreateRecentObjectForReceivedMessage:thisChatObject.contactName andDisplayName:display_name isGroup:isGroup];//TODO move in saveMessage ??? maybe
    
   thisChatObject.displayName = display_name;
   
    NSString *scClientDevId = [userData objectForKey:@"scClientDevId"];
   if(scClientDevId){
      thisChatObject.sendersDevID = scClientDevId;
   }
   
   if(location)
   {
      thisChatObject.location = location;
   }
    if (isSync)
    {
        thisChatObject = [[DBManager dBManagerInstance] updateMessageStatusForChatObject:thisChatObject userData:userData attribs:attributeDict];
    }
    
//   return -50000;//test failure to save, should send 500 internal serv error back
   int r = [self saveMessage:thisChatObject]; //we must save chat object on the same thread
    if(r)return r;
    if (thisChatObject && msgId)
        [tmpRecvMessages setObject:thisChatObject forKey:msgId];
   
   // only download attachment if application is running in foreground (active)
   if ( thisChatObject.isAttachment && (!thisChatObject.attachment.metadata)
       && ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) ) {
      // [[ChatManager sharedManager] downloadChatObjectTOC:thisChatObject];
      thisChatObject.tmpDownloadTOC = YES;
   }
   
   // post notification containing chatobject to add, for refreshing tableviews
   // only if message was not replaced
   
   if(!isSync){
      thisChatObject.tmpAddBadge = YES;
   }

   return zina::OK;
}

-(int64_t) sendForceBurnFromTheSameThread:(ChatObject *)thisChatObject
{
    int64_t v1= sendForceBurn(thisChatObject, 0);
    
    if(v1)
        sendForceBurn(thisChatObject, 1);

    return v1;
}


-(void)sendForceBurn:(ChatObject *) thisChatObject{
    
    // dont send "bn" for calls
    if (thisChatObject.isCall) {
        return;
    }

    DDLogInfo(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__, thisChatObject.displayName, thisChatObject.senderDisplayName);
    
   __block BOOL onlineAndCanSend = [Switchboard allAccountsOnline];
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if(onlineAndCanSend)
      {
         int64_t v = [self sendForceBurnFromTheSameThread:thisChatObject];//TODO if this fails to send add to stackedOfflineBurns or mark in DB
         if(!v)onlineAndCanSend = NO;
      }
      if(!onlineAndCanSend)
      {
         thisChatObject.isStoredAfterDeletion = 1;
         [self saveMessage:thisChatObject];
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            if(![[ChatUtilities utilitiesInstance].stackedOfflineBurns objectForKey:thisChatObject.msgId])
            {
                if (thisChatObject && thisChatObject.msgId)
                    [[ChatUtilities utilitiesInstance].stackedOfflineBurns setObject:thisChatObject forKey:thisChatObject.msgId];
            }
         });
      }
   });
}

-(int64_t) sendReadNotificationFromTheSameThread:(ChatObject *)thisChatObject{
   NSString *msg = thisChatObject.messageText;
   if(msg.length < 1 && !thisChatObject.attachment)return -1;
   
   
   //we have to fix api to get back resp from sibling, because it is possible that you have no siblings
   //and this method would fail
   sendReadNotification(thisChatObject, 1);
   
   int64_t v1 = sendReadNotification(thisChatObject, 0);
   return v1;
   
}


-(void) sendReadNotification:(ChatObject *) thisChatObject
{
   if (thisChatObject.isCall) {
      return;
   }
    
    DDLogInfo(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__, thisChatObject.displayName, thisChatObject.senderDisplayName);
    
    __block BOOL onlineAndCanSend = [Switchboard allAccountsOnline];
    
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      if(onlineAndCanSend)
      {
         int64_t v = [self sendReadNotificationFromTheSameThread:thisChatObject];//TODO if this fails to send add to stackedOfflineBurns or mark in DB
         if(!v)onlineAndCanSend = NO;
         if(v && thisChatObject.mustSendRead){
            thisChatObject.mustSendRead = NO;
            [self saveMessage:thisChatObject];
         }
         
      }
      
      if(!onlineAndCanSend)
      {
         thisChatObject.mustSendRead = YES;
         [self saveMessage:thisChatObject];
         
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if(![[ChatUtilities utilitiesInstance].stackedOfflineReads objectForKey:thisChatObject.msgId])
            {
                if (thisChatObject && thisChatObject.msgId)
                    [[ChatUtilities utilitiesInstance].stackedOfflineReads setObject:thisChatObject forKey:thisChatObject.msgId];
              
            }
         });
      }
   });
}

-(void)showMsgNotif:(ChatObject*)o{
    
    DDLogInfo(@"%s displayName: %@ _ senderDisplayName: %@",
              __FUNCTION__, o.displayName, o.senderDisplayName);

    void *findGlobalCfgKey(const char *key);
    
    BOOL appIsActive = ([UIApplication sharedApplication].applicationState ==  UIApplicationStateActive);
    
	if (!appIsActive) {
        
		int *showNotificationP = (int*)findGlobalCfgKey("iShowMessageNotifications");
        
		if (showNotificationP == nil || *showNotificationP == 1)
            [Switchboard.notificationsManager presentIncomingMessageNotificationForChatObject:o];
    }
    else {

        // Suppresses incoming local alert notifications
        // that have less than one second time difference
        
        BOOL showLocalAlert = NO;
        
        if(!self.lastReceivedLocalNotificationDate)
            showLocalAlert = YES;
        else if([[NSDate date] timeIntervalSinceDate:self.lastReceivedLocalNotificationDate] > 1.)
            showLocalAlert = YES;
        
        [self setLastReceivedLocalNotificationDate:[NSDate date]];
        
        if(showLocalAlert) {
            
            int *showNotificationP = (int*)findGlobalCfgKey("iShowForegroundNotifications");
            
            if ( (showNotificationP == nil) || (*showNotificationP == 1) ) {
                
                [[ChatUtilities utilitiesInstance] showLocalAlertFromChatObject:o];
                
                int *playSoundP = (int*)findGlobalCfgKey("iPlaySoundNotifications");
                BOOL bPlaySound = ( (playSoundP == nil) || (*playSoundP == 1) );

                if (bPlaySound)
                    [SPAudioManager playUserSelectedTextTone];
            }
        }
    }
}

+ (void)resendLastMessageForUUID:(NSString *)uuid deviceIds:(NSArray <NSString *> *)deviceIds {

    if(!uuid)
        return;
    
    DDLogInfo(@"%s uuid: %@ device ids: %@", __FUNCTION__, uuid, deviceIds);
    
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                                                   lowerCase:NO];
    
    NSArray *otherGroups = [GroupChatManager getGroupsWithUUID:uuid];
    
    
    for (NSString *grpId in otherGroups)
    {
        RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:grpId];
        if (recent)
        {
            ChatObject *lastChatGroupChatObject = [DBManager getLastSentChatObjectForRecent:recent];
            [[GroupChatManager sharedInstance] sendGroupMessage:lastChatGroupChatObject
                                                           uuid:uuid
                                                      deviceIds:deviceIds];
        }
    }
    
    // resend last chatobject in normal conversations
    ChatObject *chatObject = [DBManager getLastSentChatObjectForUUID:uuid];
    
    if(chatObject && !chatObject.didResendMessageAfterRescan)
    {
        chatObject.didResendMessageAfterRescan = YES;
        chatObject.iSendingNow = 1;
        
        if (chatObject.attachment)
            [[ChatManager sharedManager] uploadAttachmentForChatObject:chatObject];
        else
            [[ChatManager sharedManager] sendChatObjectAsync:chatObject];
    }
}

+ (void)removeMessages:(NSArray <NSString *> *)messages fromRecentWithID:(NSString *)recentID {
    
    for (NSString *messageId in messages) {
        
        if([messageId isEqualToString:@""])
            continue;
        
        ChatObject *thisChatObject = [[[self class] dBManagerInstance] loadEventWithMessageID:messageId
                                                                               andContactName:recentID];
        
        // if burn gets received before message, stack it and return
        if(!thisChatObject) {
            
            [[ChatUtilities utilitiesInstance].stackedBurns addObject:messageId];//remove this after 1 day, if there is no msg(but should not happen)
            [[NSUserDefaults standardUserDefaults] setObject:[ChatUtilities utilitiesInstance].stackedBurns
                                                      forKey:@"stackedBurns"];
            
            continue;
        }
        
        thisChatObject.burnNow = 1;
        thisChatObject.isRead = 1;
        thisChatObject.unixReadTimeStamp = time(NULL);
        thisChatObject.burnTime  = 2;
        thisChatObject.messageStatus = 200;
        thisChatObject.delivered = YES;
        thisChatObject.isStoredAfterDeletion =0;
        thisChatObject.iSendingNow = 0;
//#if HAS_DATA_RETENTION
//        thisChatObject.drEnabled = messageHasDR;
//#endif // HAS_DATA_RETENTION
        
        [[[self class] dBManagerInstance] removeChatMessage:thisChatObject
                                           postNotification:YES];
    }
}

@end
