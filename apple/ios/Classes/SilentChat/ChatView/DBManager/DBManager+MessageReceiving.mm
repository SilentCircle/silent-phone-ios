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
#define kReceivedMessageStatusCode 200

#import <AddressBook/AddressBook.h>
#import <AudioToolbox/AudioServices.h>

#import "DBManager+MessageReceiving.h"
#import "axolotl_glue.h"
#import "SP_FastContactFinder.h"
#import "Utilities.h"
#import "ChatManager.h"

int32_t receiveAxoMsg(const std::string& messageDescriptor, const std::string& attachementDescriptor, const std::string& messageAttributes){
    
    NSDictionary *receivedMessageInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSString stringWithUTF8String:messageDescriptor.c_str()],@"messageDescriptor",
                                         [NSString stringWithUTF8String:attachementDescriptor.c_str()],@"attachementDescriptor",
                                         [NSString stringWithUTF8String:messageAttributes.c_str()], @"messageAttributes",
                                         nil];
    
   /* dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int waittime = rand() %10;
        NSLog(@"waittime %i",waittime);
        sleep(waittime);*/
        [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessageAsJsonString" object:receivedMessageInfo];
   // });
    return  0;
}

ChatObject * getLastSentChatObject(NSString *user){
   NSMutableArray *thisUsersChatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:user];
   
   if(thisUsersChatHistory){
      for (int i = (int)thisUsersChatHistory.count ; i>0; i--) {
         ChatObject *thisChatObject = (ChatObject *) thisUsersChatHistory[i-1];
         if(thisChatObject.isReceived != 1){
            return thisChatObject;
         }
      }
   }
   return nil;
}

void stateAxoMsg(int64_t messageIdentfier, int32_t statusCode, const std::string& stateInformation){

    printf("messageIdentfier =%lld code=%d\n",messageIdentfier, statusCode);
    if(messageIdentfier == 0 && statusCode == CTAxoInterfaceBase::eMustResendLastMessage){
      
       NSString *user = [NSString stringWithUTF8String:stateInformation.c_str()];
       //Q: Should we resend only last message or last messages for last 1min?
       ChatObject *co  = getLastSentChatObject(user);
       if(co && !co.didResendMessageAfterRescan){
          co.didResendMessageAfterRescan = YES;
          //TODO resend function
          co.iSendingNow = 1;
          if (co.attachment)
             [[ChatManager sharedManager] uploadAttachmentForChatObject:co];
          else
             [[ChatManager sharedManager] sendChatObjectAsync:co];
       }
       
       return;
    }
    if(messageIdentfier == 0 && statusCode < -2 && stateInformation.length() > 0)
    {
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

                NSString *msgId = [errorDetails objectForKey:@"msgId"];
                if(msgId && msgId.length > 0)
                {
                    if([[Utilities utilitiesInstance].allChatObjects objectForKey:msgId])
                    {
                        return;
                    }
                }
                NSNumber *code = [errorDetails objectForKey:@"errorCode"];
               
               NSString *errMsg = @"Decryption failed";
               if(code){
                  errMsg = [NSString stringWithFormat:@"Decryption failed:\nError: %s.", CTAxoInterfaceBase::getErrorMsg(code.intValue) ];
               }
               
                ChatObject *thisChatObject = [[ChatObject alloc] initWithText: errMsg];
                thisChatObject.contactName = [errorDetails objectForKey:@"name"];
                thisChatObject.msgId = msgId;
                thisChatObject.errorString = stateInfo;//[NSString stringWithFormat:@"%@",errorDict];
                thisChatObject.isReceived = 1;
                thisChatObject.isRead = -1;
                [thisChatObject takeTimeStamp];
                [[DBManager dBManagerInstance] addChatObject:thisChatObject];
                
                [[Utilities utilitiesInstance] addBadgeNumberWithChatObject:thisChatObject];
                [[DBManager dBManagerInstance] saveMessage:thisChatObject];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessage" object:thisChatObject];
            });
        }
        
        return;
    }
    // if negative or 0 not sent out
    // 200 sent, ignore everything
    // 404 user doesnt exist
    // it's possible to receive status before message is sent
    ChatObject *chatObjectToChange = [[Utilities utilitiesInstance] getChatObjectByMessageIdentifier:messageIdentfier];
    if(!chatObjectToChange){
        [[DBManager dBManagerInstance].cachedMessageStatuses setValue:[NSString stringWithFormat:@"%d",statusCode] forKey:[NSString stringWithFormat:@"%lld",messageIdentfier]];
    }
    else if(chatObjectToChange.messageStatus != kReceivedMessageStatusCode)
    {
        if(!chatObjectToChange.didPlaySentSound && (statusCode==200 || statusCode==202)){
            chatObjectToChange.didPlaySentSound = YES;
            [[Utilities utilitiesInstance] playSoundFile:@"sent" withExtension:@"aiff"];
        }
        if(chatObjectToChange.messageStatus != statusCode){
            //if we have 200 ignore other codes, if we have more eaqual than 200 ignore all error messages
            if((chatObjectToChange.messageStatus == 202 && statusCode == 200) ||
               (chatObjectToChange.messageStatus < 200 && statusCode >= 200) ||
               (chatObjectToChange.messageStatus > 202 && (statusCode == 202 || statusCode == 200)) ||
               (chatObjectToChange.messageStatus == 0 && statusCode != 0))
            {
                chatObjectToChange.messageStatus = statusCode;
                [[DBManager dBManagerInstance] saveMessage:chatObjectToChange];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessageState" object:chatObjectToChange];
            }
        }
    }
}

static void sendForceBurn(ChatObject *thisChatObject, int mySelf){
   NSString *msg = thisChatObject.messageText;
   if(msg.length<1 && !thisChatObject.attachment)return;
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      
      NSString *ownUN = [[Utilities utilitiesInstance] getOwnUserName];

      NSString *msgID = thisChatObject.msgId;
      NSString *userName = [[Utilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:YES] ;
      
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
                  "\"rr_time\": %ld"
                  "}"
                  ,time(NULL)
                  );
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
      CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(buf, NULL, bufAttribs);
   });
}

void sendForceBurn(ChatObject *thisChatObject){
   sendForceBurn(thisChatObject, 0);
   sendForceBurn(thisChatObject, 1);
}

void sendDeliveryNotification(ChatObject *thisChatObject){
   
    NSString *msg = thisChatObject.messageText;
    if(msg.length < 1 && !thisChatObject.attachment)return;
   
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
       
        NSString *msgID = thisChatObject.msgId;
        NSString *userName =[[Utilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:YES] ;
       
        usleep((random()&0xff)*100+200*1000);
        
        char buf[1024];
        snprintf(buf, sizeof(buf)-1,
                 "{"
                 "\"version\": 1,"
                 "\"recipient\": \"%s\","
                 "\"deviceId\": 1,"
                 "\"msgId\":\"%s\","
                 "\"message\":\"\""
                 "}"
                 ,userName.UTF8String
                 ,msgID.UTF8String
                 );
        
        char bufAttribs[512];
        
        snprintf(bufAttribs, sizeof(bufAttribs)-1,
                 "{"
                 "\"cmd\":\"rr\","
                 "\"rr_time\": %ld"
                 "}"
                 ,time(NULL)
                 );
        
        CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(buf, NULL, bufAttribs);
    });
    
}

@implementation DBManager (MessageReceiving)
// save burn notice timers in chatobject
-(void) receiveMessageAsJsonString:(NSNotification*) info{
    
    NSDictionary *receivedMessageInfo = (NSDictionary*) info.object;
    
    NSString *messageDataString = [receivedMessageInfo objectForKey:@"messageDescriptor"];
    NSData *data = [messageDataString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *userData = [NSJSONSerialization JSONObjectWithData:data
                                                             options:kNilOptions
                                                               error:nil];

    NSString *attributeDataString = [receivedMessageInfo objectForKey:@"messageAttributes"];
    NSData *attributeData = [attributeDataString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributeDict= [NSJSONSerialization JSONObjectWithData:attributeData
                                                               options:kNilOptions
                                                                 error:nil];

    NSString *attachmentDataString = [receivedMessageInfo objectForKey:@"attachementDescriptor"];
    NSData *attachmentData = ([attachmentDataString length] > 0) ? [attachmentDataString dataUsingEncoding:NSUTF8StringEncoding] : nil;
    NSDictionary *attachmentDict = (attachmentData) ? [NSJSONSerialization JSONObjectWithData:attachmentData options:kNilOptions error:nil] : nil;
    
    NSString *messageText = [userData objectForKey:@"message"];
    NSString *contactName = [userData objectForKey:@"sender"];
    NSString *msgId = [userData objectForKey:@"msgId"];
    
    int burnDelayTime = 0;
    CLLocation *location;
    
    BOOL isSync = NO;
	
	if ( (messageText.length < 1) && (!attachmentDict) )
    {
       
       NSString *syc = [attributeDict objectForKey:@"syc"];
       if(syc && syc.length > 0){
          NSString *destination = [attributeDict objectForKey:@"or"];
          if(!destination)return;
          contactName = destination;
       }
       
        ChatObject *thisChatObject = [[Utilities utilitiesInstance] getChatObjectByMsgId:msgId andContactName:[[Utilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES]];
        
        if(!thisChatObject)
        {
            return;
        }
        NSString *cmd = [attributeDict objectForKey:@"cmd"];
        // NSString *contactName = [attributesData objectForKey:@"sender"];
        if([cmd isEqualToString:@"bn"]){
            thisChatObject.burnNow = 1;
            thisChatObject.isRead = 1;
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:NO];
        }
        else if([cmd isEqualToString:@"rr"]){//read notice
            //
            //start
            thisChatObject.isRead = 1;
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:NO];
            if(thisChatObject.messageStatus!=200){
               thisChatObject.messageStatus = 200; // and this also means that it was really deliverend
            }
            [self saveMessage:thisChatObject];
            //NSString *rr_time = [attributesData objectForKey:@"rr_time"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessageState" object:thisChatObject];
        }
        return;
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
        
        NSString *cmd = [attributeDict objectForKey:@"syc"];
        // NSString *contactName = [attributesData objectForKey:@"sender"];
        if([cmd isEqualToString:@"om"]){
             NSString *destination = [attributeDict objectForKey:@"or"];
            contactName = destination;
            isSync = YES;
            
        }
        //{"syc":"om","r":true,"or":"gosis2"}
        /*
        if(attributeDataString.length > 0 && messageText.length>0){
            NSString *cmd = [attributesData objectForKey:@"syc"];
            if([cmd isEqualToString:@"om"]){
            }
        }
         */
    }
   // sendDeliveryNotification(messageDataString);

    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
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
			thisChatObject = [[ChatObject alloc] initWithAttachment:attachment];
        } else
            thisChatObject = [[ChatObject alloc] initWithText:messageText];

        // if object with this msgid doesnt exist, add it,
        // if it exists, find and replace it, post status update to change info to display for this message
        BOOL msgIdExists = NO;
        if(![[Utilities utilitiesInstance].allChatObjects objectForKey:msgId])
        {
            msgIdExists = NO;
        } else
        {
            msgIdExists = YES;
        }
		thisChatObject.contactName = contactName;
        thisChatObject.isReceived = isSync ? 0 : 1;
        thisChatObject.isRead = isSync ? 0 : -1;//start burn timer
        thisChatObject.msgId = msgId;
        thisChatObject.isSynced = isSync;
        thisChatObject.burnTime = burnDelayTime;
        [thisChatObject takeTimeStamp];
        if(location)
        {
            thisChatObject.location = location;
        }
        if(!msgIdExists)
        {
            [self addChatObject:thisChatObject];
        } else
        {
            NSMutableArray *chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:thisChatObject.contactName];
             for (long i = chatHistory.count-1; i>=0; i--) {
                 ChatObject *chatObject = (ChatObject *)chatHistory[i];
                 if([chatObject.msgId isEqualToString:msgId])
                 {
                     [chatHistory replaceObjectAtIndex:i withObject:thisChatObject];
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessageState" object:thisChatObject];
                 }
            }
        }
        
        [[Utilities utilitiesInstance] addBadgeNumberWithChatObject:thisChatObject];
        
        // save message in database
        [self saveMessage:thisChatObject];
		
		// only download attachment if application is running in foreground (active)
		if ( (thisChatObject.attachment) && (!thisChatObject.attachment.metadata)
				&& ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) ) {
			[[ChatManager sharedManager] downloadChatObjectTOC:thisChatObject];
		}
		
        // post notification containing chatobject to add, for refreshing tableviews
        // only if message was not replaced
        if(!msgIdExists)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessage" object:thisChatObject];
        
        if(!isSync && !msgIdExists){
            [self showNotif:thisChatObject];
            
        }
        
    });
    
}

-(void)addChatObject:(ChatObject*)receivedChatObject{
    
    //Save received message in utilities chatHistory
    NSMutableArray *thisUsersChatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:receivedChatObject.contactName];
    if(!thisUsersChatHistory)
    {
        thisUsersChatHistory = [[NSMutableArray alloc] init];
        [[Utilities utilitiesInstance].chatHistory setValue:thisUsersChatHistory forKey:receivedChatObject.contactName];
    }
    
    NSUInteger indexToInsert = thisUsersChatHistory.count;
    if(thisUsersChatHistory.count > 1)
    {

        const long long usec_per_sec = 1000000;
        long long tRecevived = (long long)receivedChatObject.timeVal.tv_sec * usec_per_sec + (long long)receivedChatObject.timeVal.tv_usec;
        
        for (int i = (int)thisUsersChatHistory.count ; i>0; i--) {
            ChatObject *thisChatObject = (ChatObject *) thisUsersChatHistory[i-1];
            
            indexToInsert = i;
            
            if(thisChatObject.isReceived != 1 && !thisChatObject.isSynced)break;
            
            long long tThis = (long long)thisChatObject.timeVal.tv_sec * usec_per_sec + (long long)thisChatObject.timeVal.tv_usec;
            
            if(tRecevived > tThis)
            {
                break;
            }
            
        }
    }
    
    // indexPathToInsert = [NSIndexPath indexPathForRow:indexToInsert inSection:0];
    
    [thisUsersChatHistory insertObject:receivedChatObject atIndex:indexToInsert];
}

-(void)sendForceBurn:(ChatObject *) thisChatObject{
   sendForceBurn(thisChatObject);
}

-(void) sendDeliveryNotification:(ChatObject *) thisChatObject
{
    sendDeliveryNotification(thisChatObject);
}

-(void)showNotif:(ChatObject*)o{
    
    if ([UIApplication sharedApplication].applicationState !=  UIApplicationStateActive) {
        // Create a new notification
        UILocalNotification* notif = [[UILocalNotification alloc] init];
        if (notif) {
            notif.repeatInterval = 0;
            notif.alertAction = nil;//?? c->incomCallPriority
            int idx;
            NSString *ns = [SP_FastContactFinder findPerson:o.contactName idx:&idx];
            if(!ns) ns = o.displayName;
           
           //   GLOB_SZ_CHK_O(szMessageNotifcations, "Notification only,Sender only,Message+Sender
           
            const char* sendEngMsg(void *pEng, const char *p);
            const char *mn = sendEngMsg(NULL,"cfg.szMessageNotifcations");
           
            if(strcmp(mn, "Notification only")==0){
               notif.alertBody = @"You have a new text message";
            }
            else if(strcmp(mn, "Sender only")==0){
               notif.alertBody = [NSString stringWithFormat:@"Message from: %@",ns ];
            }
            else {
               if(o.messageText == nil || o.messageText.length < 1){
                  notif.alertBody = [NSString stringWithFormat:@"Attachment from: %@",ns ];
               }
               else{
                  notif.alertBody = [NSString stringWithFormat:@"Message from: %@\n%@",ns, o.messageText ];
               }
            }
           
            notif.soundName = UILocalNotificationDefaultSoundName;//@"received.wav";
            notif.userInfo = @{@"contactName":o.contactName};
            
            [[UIApplication sharedApplication]  presentLocalNotificationNow:notif];
            
            //TODO cancel notifcations when message opened
            // also open chatviewcontroller when user responds to notification
        }
    }
    else {
        //[[Utilities utilitiesInstance] showLocalAlertFromUser:o];
        [[Utilities utilitiesInstance] playSoundFile:@"received" withExtension:@"wav"];
    }
}
@end
