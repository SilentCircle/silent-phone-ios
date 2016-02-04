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
#import "appRepository/AppRepository.h"
#include <cryptcommon/aescpp.h>

#import "DBManager.h"
#import "DBManager+MessageReceiving.h"
//#import <sqlite3.h>
#import "RecentObject.h"
#import "Utilities.h"


using namespace axolotl;

static AppRepository *db = NULL;

@implementation DBManager
{
  //  sqlite3 *chatMEssagesDB;
    NSArray *paths;
    NSString *documentsDirectory;
    NSString *databasePath;
    
    NSMutableArray *tempChatHistoryArray;
}

+(DBManager *)dBManagerInstance
{
    static dispatch_once_t once;
    static DBManager *dBManagerInstance;
    dispatch_once(&once, ^{
        dBManagerInstance = [[self alloc] init];
        
        CTAxoInterfaceBase::setCallbacks(stateAxoMsg, receiveAxoMsg);
        
        
        dBManagerInstance->paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        dBManagerInstance->documentsDirectory = [dBManagerInstance->paths objectAtIndex:0];

        dBManagerInstance->databasePath = [[NSString alloc]initWithString:[dBManagerInstance->documentsDirectory stringByAppendingPathComponent:@"ChatMessages_cipher.db"]];
        
        db = AppRepository::getStore();
       
        unsigned char *get32ByteAxoKey(void);
        unsigned char *key = get32ByteAxoKey();
        std::string dbPw((const char*)key, 32);
        db->setKey(dbPw);
        db->openStore(dBManagerInstance->databasePath.UTF8String);
        [dBManagerInstance getDatabase];
    });
    return dBManagerInstance;
}

-(void)getDatabase
{
    [self loadAllConversations];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveMessageAsJsonString:)
                                                 name:@"receiveMessageAsJsonString" object:nil];
}

#pragma mark message saving
/**
 * Save Message
 **/
-(long) saveMessage:(ChatObject*)thisChatObject
{
	if (thisChatObject.attachment) {
		// take new timestamp to contain seconds
		NSDate *currentTime = [NSDate date];
		NSString *attachmentName = [NSString stringWithFormat:@"%@-%ld",thisChatObject.msgId, (unsigned long)[currentTime timeIntervalSince1970]];
		attachmentName = [attachmentName stringByReplacingOccurrencesOfString:@" " withString:@""];
		NSString *attachmentPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.sc", attachmentName]];
		
		[thisChatObject.attachment writeToFile:attachmentPath atomically:YES];
		thisChatObject.attachmentName = attachmentName;
	}
	
    [self saveEvent:thisChatObject];
    return 0;
}

/**
 * Save image and it's thumbnail in documents directory
 * call saveMessage
 **/
/*
-(void) saveImageMessage:(ChatObject*) thisChatObject
{
    // take new timestamp to contain seconds
    NSDate *currentTime = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"d MMM yyyy HH:mm:ss"];
    NSString *imageNameWithSpaces = [NSString stringWithFormat:@"%@%@",thisChatObject.contactName,[dateFormatter stringFromDate: currentTime]];
    NSString *imageName = thisChatObject.msgId;
    
    
    // save thumbnail and full image
    NSData *imageData = [NSData dataWithData:UIImagePNGRepresentation(thisChatObject.image)];
    NSData *imageThumbnailData = [NSData dataWithData:UIImagePNGRepresentation(thisChatObject.imageThumbnail)];
    
    NSString *imagePathForFullImage = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@_full.png",imageName]];
    [imageData writeToFile:imagePathForFullImage atomically:YES];
    
    NSString *imagePathForThumbnail = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@_thumb.png",imageName]];
    [imageThumbnailData writeToFile:imagePathForThumbnail atomically:YES];

//    thisChatObject.imageName = imageName;

[self saveMessage:thisChatObject];
    
}
*/

-(UIImage *) getfullImageFromDocumentsByName:(NSString *) imageName
{
    NSString *fullImagePath =[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@_full.png",imageName]];
   return [UIImage imageWithContentsOfFile:fullImagePath];
}

#pragma mark remove messages

-(void) removeChatWithContact:(RecentObject*) recentToRemove
{

    [self deleteConversationWithName:recentToRemove.contactName];
}

/**
 * Remove single message from chatview by msgId
 **/
-(void) removeChatMessage:(ChatObject*) chatObjectToRemove
{
    [self deleteEvent:chatObjectToRemove];
}

// DB using werners AppRepository.h
#pragma mark DBManager_V2


/**
 * list of all usernames for conversations
 **/
-(void) loadAllConversations
{
  list<string>* conversationList =  db->listConversations();
    
    while (!conversationList->empty()) {
        std::string resultStr = conversationList->front();
        
        [self loadConversationWithName:[NSString stringWithUTF8String:resultStr.c_str()]];
        conversationList->erase(conversationList->begin());
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateRecents" object:nil];
}

-(void) loadConversationWithName:(NSString*) name
{
    std:: string data;
    db->loadConversation(name.UTF8String, &data);

   
    NSString *ns = [self decryptData:name.UTF8String dataFromDB:data];
    if(!ns)
    {
        return;
    }
    NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
    
    NSString *contactName =  [JSONDict objectForKey:@"contactName"];
    NSString *displayName =  [JSONDict objectForKey:@"displayName"];
    int hasBurnBeenSet =  [[JSONDict objectForKey:@"hasBurnBeenSet"] intValue];
 //--   NSString *lastMessageContent =  [JSONDict objectForKey:@"lastMessageContent"];
   //-- int unixTimeStamp = [[JSONDict objectForKey:@"unixTimeStamp"] intValue];
    
    int burnDelayDuration = [[JSONDict objectForKey:@"burnDelayDuration"] intValue];
    int shareLocationTime = [[JSONDict objectForKey:@"shareLocationTime"] intValue];
    RecentObject *thisRecent = [[RecentObject alloc] init];
    thisRecent.contactName = contactName;
    //thisRecent.lastMessageContent = lastMessageContent;
   //-- thisRecent.unixTimeStamp = unixTimeStamp;
    
    thisRecent.displayName = displayName;
    if(hasBurnBeenSet)
    {
        thisRecent.hasBurnBeenSet = hasBurnBeenSet;
    }
    thisRecent.burnDelayDuration = burnDelayDuration;
    thisRecent.shareLocationTime = shareLocationTime;
    
    int messageCountForThisRecent = [self loadAllEventsForContactName:name];
	
    NSMutableArray * chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:name];
    
    if(chatHistory.lastObject){
        thisRecent.unixTimeStamp = ((ChatObject*)(chatHistory.lastObject)).unixTimeStamp;
    }
    else thisRecent.unixTimeStamp = 0;
    /*
    // if there are no messages for this contact, set this recents lastmessage value to empty string
    if(messageCountForThisRecent <=0)
    {
        thisRecent.lastMessageContent = @"";
    }*/
    [[Utilities utilitiesInstance].recents setValue:thisRecent forKey:contactName];
    
    
}

-(BOOL) existsConversation:(NSString *) name
{
    return db->existConversation(name.UTF8String);
}

-(void) insertOrUpdateConversation:(ChatObject*)thisChatObject
{
    
    // at this point recent should exist for contactname
    RecentObject *thisRecent = [[Utilities utilitiesInstance].recents objectForKey:thisChatObject.contactName];
    if(!thisRecent)
        return;
    thisRecent.unixTimeStamp = thisChatObject.unixTimeStamp;
    //thisRecent.lastMessageContent = thisChatObject.messageText;
    
    NSError *writeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:thisRecent.dictionary options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
   // db->storeConversation(thisChatObject.contactName.UTF8String, jsonString.UTF8String);

   
   // void encryptData(const char *name, const char *msg, int iMsgSize, std::string & str)
    std::string str;
    encryptData(thisChatObject.contactName.UTF8String, jsonString,str);
    db->storeConversation(thisChatObject.contactName.UTF8String, str);
}

-(void) deleteConversationWithName:(NSString *) name
{
	NSArray *messageList = [[Utilities utilitiesInstance].chatHistory objectForKey:name];
	for (ChatObject *chatObject in messageList)
		[self deleteEvent:chatObject];

	db->deleteEventName(name.UTF8String);
    db->deleteConversation(name.UTF8String);
    [[Utilities utilitiesInstance].chatHistory removeObjectForKey:name];
}

void encryptData(const char *name, NSString *nsToEncrypt, std::string & str){
   unsigned char *get32ByteAxoKey(void);
   unsigned char *key = get32ByteAxoKey();
   
   AESencrypt aes;
   
   aes.key256((const uint8_t*)key);
   
   int len = (int)[nsToEncrypt lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
   
   // Decrypt the session data and initialize a conversation
   uint8_t* sessionEnc = new uint8_t[len+1];
   unsigned char iv[] = "0123456789abcdef0123456789abcdef";
   
   snprintf((char*)iv, sizeof(iv),"%s",name);
   
   aes.cfb_encrypt((unsigned char*)nsToEncrypt.UTF8String, sessionEnc, len, iv);
   str.assign((char *)sessionEnc, len);
   delete sessionEnc;
}

-(NSString *)decryptData:(const char *)name dataFromDB: (std::string &) dataFromDB{
   unsigned char *get32ByteAxoKey(void);
   unsigned char *key = get32ByteAxoKey();
   
   AESencrypt aes;
   
   aes.key256((const uint8_t*)key);
   
   int len = (int)dataFromDB.size();
   
   // Decrypt the session data and initialize a conversation
   uint8_t* sessionDec = new uint8_t[len+1];
   unsigned char iv[] = "0123456789abcdef0123456789abcdef";
   
   snprintf((char*)iv, sizeof(iv),"%s", name);
   
   aes.cfb_decrypt((unsigned char*)dataFromDB.data(), sessionDec, len, iv);
   
   sessionDec[len]=0;
   
   NSString *ns = [NSString stringWithUTF8String:(char*)sessionDec];
   
   delete sessionDec;
   return ns;
   /*
   
   AESencrypt aes;
   
   aes.key256((const uint8_t*)key);
   
   int len = iMsgSize;
   
   // Decrypt the session data and initialize a conversation
   uint8_t* sessionEnc = new uint8_t[len+1];
   unsigned char iv[] = "0123456789abcdef0123456789abcdef";
   
   snprintf((char*)iv, sizeof(iv),"%s",un);
   
   aes.cfb_encrypt((unsigned char*)msg, sessionEnc, len, iv);
   str.assign((char *)sessionEnc, len);
   delete sessionEnc;
    */
}

-(void)saveEvent:(ChatObject *)thisChatObject
{
    NSError *writeError = nil;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:thisChatObject.dictionary options:NSJSONWritingPrettyPrinted error:&writeError];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];


   // std:: string data;
   //-------------------
   /*
   unsigned char *get32ByteAxoKey(void);
   unsigned char *key = get32ByteAxoKey();
   
   AESencrypt aes;
   
   aes.key256((const uint8_t*)key);
   
   int len = jsonString.length;
   
   // Decrypt the session data and initialize a conversation
   uint8_t* sessionEnc = new uint8_t[len+1];
   unsigned char iv[] = "0123456789abcdef0123456789abcdef";
   
   snprintf((char*)iv, sizeof(iv),"%s",thisChatObject.contactName.UTF8String);
   
   aes.cfb_encrypt((unsigned char*)jsonString.UTF8String, sessionEnc, len, iv);
   
   std::string str;//((char*)sessionEnc, len);
    */
   //-------------------------
   
    std::string str;
    encryptData(thisChatObject.contactName.UTF8String, jsonString, str);
   
 //   db->storeConversation(thisChatObject.contactName.UTF8String, str);//TODO str
    db->insertEvent(thisChatObject.contactName.UTF8String, thisChatObject.msgId.UTF8String, str);

    
    RecentObject *recentToUpdate = [[Utilities utilitiesInstance].recents objectForKey:thisChatObject.contactName];
    if(!recentToUpdate)
    {
        recentToUpdate = [[RecentObject alloc] init];
        [[Utilities utilitiesInstance].recents setValue:recentToUpdate forKey:thisChatObject.contactName];
        recentToUpdate.contactName = thisChatObject.contactName;
        recentToUpdate.hasBurnBeenSet = 0;
        recentToUpdate.burnDelayDuration = [Utilities utilitiesInstance].kDefaultBurnTime;
    }
    recentToUpdate.unixTimeStamp = thisChatObject.unixTimeStamp;
   // recentToUpdate.lastMessageContent = thisChatObject.messageText;
    
    // update conversation with last message sent or received
    [self insertOrUpdateConversation:thisChatObject];
}

-(void) deleteEvent:(ChatObject*)thisChatObject
{
    NSTimer *timer = [[Utilities utilitiesInstance].burnTimers objectForKey:thisChatObject.msgId];
    if(timer)
    {
        [timer invalidate];
        [[Utilities utilitiesInstance].burnTimers removeObjectForKey:thisChatObject.msgId];
    }
    [[Utilities utilitiesInstance] removeBadgeNumberForChatObject:thisChatObject];
	
	[thisChatObject deleteAttachment];
	
	if (thisChatObject.contactName && thisChatObject.msgId)
		db->deleteEvent(thisChatObject.contactName.UTF8String, thisChatObject.msgId.UTF8String);
}

/**
 * Loads messages for user with username in descending order
 *@return number of messages returned from db
 **/
-(int) loadAllEventsForContactName:(NSString *)name
{
    std:: list<std::string*> allEventsList;
    std::int32_t lastMessageNumber = 0;
    db->loadEvents(name.UTF8String, -1, -1, &allEventsList, &lastMessageNumber);
    
    NSMutableArray *messagesWithThisContact = [[NSMutableArray alloc] init];
    // last taken chatobject
    // meant to replace conversation last object when last gets deleted

    while (!allEventsList.empty()) {
        std::string resultStr = *allEventsList.front();
       
       
       NSString *ns = [self decryptData:name.UTF8String dataFromDB:resultStr];

       
        NSData *JSONData = [ns dataUsingEncoding:NSUTF8StringEncoding];

        NSDictionary *JSONDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:nil];
        NSString *messagetext = [JSONDict objectForKey:@"messageText"];
        NSString *contactName = [JSONDict objectForKey:@"contactName"];

        
        NSString *isRead = [JSONDict objectForKey:@"isRead"];
        NSString *isReceived = [JSONDict objectForKey:@"isReceived"];
        NSString *msgId = [JSONDict objectForKey:@"msgId"];
        
//        NSString *imageName = [JSONDict objectForKey:@"imageName"];
		
        long messageStatus = [[JSONDict objectForKey:@"messageStatus"] longLongValue];
        long long messageIdentifier = [[JSONDict objectForKey:@"messageIdentifier"] longLongValue];
        int unixTimeStamp = [[JSONDict objectForKey:@"unixTimeStamp"] intValue];
        int unixReadTimeStamp = [[JSONDict objectForKey:@"unixReadTimeStamp"] intValue];
        int burnTime = [[JSONDict objectForKey:@"burnTime"] intValue];
        int hasFailedAttachment = [[JSONDict objectForKey:@"hasFailedAttachment"] intValue];
        
        BOOL isSynced = [[JSONDict objectForKey:@"isSynced"] boolValue];
        
        NSString *errorString = [JSONDict objectForKey:@"errorString"];
        
        NSDictionary *locationDict = [JSONDict objectForKey:@"location"];
        
        
        CLLocation *location = nil;
        if(locationDict)
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

		NSString *cloudLocator = [JSONDict objectForKey:@"cloudLocator"];
		NSString *cloudKey = [JSONDict objectForKey:@"cloudKey"];
		NSArray *segmentList = [JSONDict objectForKey:@"segmentList"];

        SCAttachment *attachment = nil;
        NSString *attachmentName = [JSONDict objectForKey:@"attachment"];
        if ([attachmentName length] > 0) {
            NSString *attachmentPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.sc", attachmentName]];

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
        //if there is no message status then probably and
        //the APP did exit and we have not deliver
        if([isReceived intValue] != 1 && messageStatus == 0){
            messageStatus = -2;
        }
       
        ChatObject *thisChatObject = (attachment) ? [[ChatObject alloc] initWithAttachment:attachment]
                                                  : [[ChatObject alloc] initWithText:messagetext];
        thisChatObject.messageText = messagetext;
        thisChatObject.contactName = contactName;
        thisChatObject.unixTimeStamp = unixTimeStamp;
        thisChatObject.unixReadTimeStamp = unixReadTimeStamp;
        thisChatObject.isRead = [isRead intValue];
        thisChatObject.isReceived = [isReceived intValue];
        thisChatObject.msgId = msgId;
        thisChatObject.errorString = errorString;
        thisChatObject.isSynced = isSynced;
        thisChatObject.messageStatus = messageStatus;
        thisChatObject.messageIdentifier = messageIdentifier;
        thisChatObject.burnTime = burnTime;
        thisChatObject.hasFailedAttachment = hasFailedAttachment;

        if(location)
        {
            thisChatObject.location = location;
        }
        // if burn time is in the past, delete message from db
        // else add message to burnTimers dictionary and perform remove chatobject selector after burnTime
        if(unixReadTimeStamp && burnTime + unixReadTimeStamp < time(NULL) && burnTime != 0)
        {
            [self removeChatMessage:thisChatObject];
           
        } else
        {
            if(thisChatObject.isReceived && thisChatObject.isRead != 1){
               [[Utilities utilitiesInstance] addBadgeNumberWithChatObject:thisChatObject];
            }
            
            [self setOffBurnTimerForBurnTime:burnTime andChatObject:thisChatObject checkForRemoveal:NO];
            [messagesWithThisContact addObject:thisChatObject];
        }
    
        
        allEventsList.erase(allEventsList.begin());
    }
    if(messagesWithThisContact.count > 0)
    {
        NSSortDescriptor *sortDescriptor;
        sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"unixTimeStamp"
                                                     ascending:YES];
        NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
        
        NSMutableArray *results = [[messagesWithThisContact sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
        messagesWithThisContact = results;
        
      ///  [[Utilities utilitiesInstance].chatHistory setValue:messagesWithThisContact forKey:name];

        tempChatHistoryArray = [[NSMutableArray alloc] init];
        NSMutableArray *result =[[NSMutableArray alloc] init];

        
        for (ChatObject * thisChatObject in messagesWithThisContact) {
            if(thisChatObject.isReceived == 1 || thisChatObject.isSynced){

                [tempChatHistoryArray addObject:thisChatObject];
            }
            else
            {
                if(tempChatHistoryArray.count>0){
                    if(tempChatHistoryArray.count>1){
                        NSArray *sorted = [self sort:tempChatHistoryArray];
                        
                        [result addObjectsFromArray:sorted];
                    }else{
                        [result addObjectsFromArray:tempChatHistoryArray];
                    }
                    [tempChatHistoryArray removeAllObjects];
                    
                }
                [result addObject:thisChatObject];
          
            }

        }
        if(tempChatHistoryArray.count>0){
            if(tempChatHistoryArray.count>1){
                NSArray *sorted = [self sort:tempChatHistoryArray];
                
                [result addObjectsFromArray:sorted];
            }else{
                [result addObjectsFromArray:tempChatHistoryArray];
            }
            [tempChatHistoryArray removeAllObjects];
            
        }
        [[Utilities utilitiesInstance].chatHistory setValue:result forKey:name];
        return (int)result.count;

    }
   
    return (int)messagesWithThisContact.count;
}

-(NSArray *) sort:(NSMutableArray *)arrayToSort
{
    NSArray *sortedArray = [arrayToSort sortedArrayUsingComparator:^(id obj1, id obj2) {
        
        ChatObject *chat1 = (ChatObject *) obj1;
        ChatObject *chat2 = (ChatObject *) obj2;
        //typedef NS_ENUM(NSInteger, NSComparisonResult) {NSOrderedAscending = -1L, NSOrderedSame, NSOrderedDescending};
        const long long usec_per_sec = 1000000;
        long long t1 = (long long)chat1.timeVal.tv_sec * usec_per_sec + (long long)chat1.timeVal.tv_usec;
        long long t2 = (long long)chat2.timeVal.tv_sec * usec_per_sec + (long long)chat2.timeVal.tv_usec;
        if(t1 > t2) return (NSComparisonResult)NSOrderedDescending;
        if(t1 < t2) return (NSComparisonResult)NSOrderedAscending;
        return (NSComparisonResult)NSOrderedSame;
    }];
    return sortedArray;
}



#pragma mark burnTimer
/**
 * Launches nstimer when chatObject gets taken out of database
 * saves nstimers in utilities, for now not used
 **/
-(void) setOffBurnTimerForBurnTime:(long) burnTime andChatObject:(ChatObject*) thisChatObject checkForRemoveal:(BOOL) shouldRemove
{
    
    if(thisChatObject.burnNow  || (burnTime > 0 && thisChatObject.unixReadTimeStamp))
    {
        // 3 - poof animation time
        if(thisChatObject.burnNow){
           burnTime = time(NULL) + 3;
        }
        else{
            burnTime += thisChatObject.unixReadTimeStamp + 3;
        }
        if(burnTime - time(NULL) > 0){
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // if burntimer exists, dont reset, unless function gets called from applicationWillEnterForeground
                if(!thisChatObject.burnTimer || shouldRemove)
                {
                    if(thisChatObject.burnTimer)
                    {
                        [thisChatObject.burnTimer invalidate];
                    }
                    NSTimer *burnTimer = [NSTimer timerWithTimeInterval:burnTime - time(NULL) target:self selector:@selector(removeChatObjectAfterTimer:) userInfo:thisChatObject repeats:NO];
                    [[NSRunLoop currentRunLoop] addTimer:burnTimer forMode:NSRunLoopCommonModes];
                    thisChatObject.burnTimer = burnTimer;
                    [[Utilities utilitiesInstance].burnTimers setValue:burnTimer forKey:thisChatObject.msgId];
                }
            });
        }
        else if(shouldRemove){
            [self removeChatObject:thisChatObject];
        }
    }
}

/**
 * Called after timer finishes, removes all trace from chatobject and badgenumber associated with it
 **/
-(void) removeChatObjectAfterTimer:(NSTimer*) timer
{
    ChatObject *chatObjectToRemove = (ChatObject*) timer.userInfo;
    [self removeChatObject:chatObjectToRemove];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateRecents" object:nil];

}

-(void) removeChatObject:(ChatObject*) chatObjectToRemove
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"removeMessage" object:chatObjectToRemove];
        
        [self removeChatMessage:chatObjectToRemove];
        
        NSMutableArray *thisContactsChatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:chatObjectToRemove.contactName];
        
        if([thisContactsChatHistory containsObject:chatObjectToRemove]){
            [thisContactsChatHistory removeObjectIdenticalTo:chatObjectToRemove];
        }
        
    });
}


@end
