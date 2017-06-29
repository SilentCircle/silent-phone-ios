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

#import <Foundation/Foundation.h>
#import "ChatObject.h"
#import "RecentObject.h"

#define SC_DB_ERR_CODE_OFFSET -10000

@interface  DBManager: NSObject{
   @private NSMapTable *tmpRecvMessages;
   
}

+(DBManager *)dBManagerInstance;
+(void) setup;

-(int) saveMessage:(ChatObject*)thisChatObject;


-(void) removeChatWithContact:(RecentObject*) recentToRemove;

-(void) removeChatMessage:(ChatObject*) thisChatObject postNotification:(BOOL) post;

-(ChatObject *) loadEventWithMessageID:(NSString *) msgID andContactName:(NSString *) contactName;

//will not and must not search in DB
//we use this only when we send out a message and want to get back a responce code
-(ChatObject*) getRecentlySentChatObjectByMessageIdentifier:(long long) messageIdentifier;
-(void)addChatObjectToRecentlySent:(ChatObject *)co msgDeliveryId:(long long)msgDeliveryId;


-(void)markAsSendingChatObject:(ChatObject *)co mark:(BOOL)mark;
-(BOOL)isSendingNowChatObject:(ChatObject *)co;


-(void) setOffBurnTimerForBurnTime:(long) burnTime andChatObject:(ChatObject*) thisChatObject checkForRemoveal:(BOOL) shouldRemove;

@property (nonatomic) NSDate *lastReceivedLocalNotificationDate;

@property (nonatomic, strong) NSMutableDictionary *cachedMessageStatuses;//TODO fix: make it hashtable

-(int) saveRecentObject:(RecentObject*) thisRecent;
-(NSArray *)getRecents;

-(NSMutableArray *) loadEventsForRecent:(RecentObject *)recent offset:(int)offset count:(int) count completionBlock:(void (^)(NSMutableArray *array, int lastMsgNumber)) completion;



-(RecentObject*)getRecentByName:(NSString *)name;
-(BOOL)existsRecentByName:(NSString *)name;
-(BOOL) existEvent:(NSString *) msgID andContactName:(NSString *) contactName;
-(RecentObject *) getOrCreateRecentObjectForReceivedMessage:(NSString *) uuid andDisplayName:(NSString *) displayName isGroup:(BOOL) isGroup;
-(RecentObject *) getOrCreateRecentObjectWithContactName:(NSString *) contactName;


-(ChatObject *) getLastChatObjectForName:(NSString *) contactName;

-(void) deleteMessagesBeforeBurnTime:(int) burnTime uuid:(NSString *) uuid;

-(void) loadBackgroundTasks;

-(void) markMessagesAsReadForConversation:(RecentObject *) recent;
@end
