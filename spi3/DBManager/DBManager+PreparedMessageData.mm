//
//  DBManager+PreparedMessageData.m
//  SPi3
//
//  Created by Gints Osis on 25/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "DBManager+PreparedMessageData.h"
#include "interfaceApp/AppInterfaceImpl.h"
#import "axolotl_glue.h"
#import "SCSEnums.h"
#import "ChatUtilities.h"
#import "ChatManager.h"
#import "SCPNotificationKeys.h"

using namespace zina;
using namespace std;

@implementation DBManager (PreparedMessageData)

-(NSArray *) getPreparedMessageData:(NSString *) messageDescriptor attachmentDescriptor:(NSString *)attachmentDescriptor  attribs:(NSString *) attribs
{
    NSMutableArray *messageData = [[NSMutableArray alloc] init];
    string messageDescriptorString = messageDescriptor.UTF8String;
    string attachmentDescriptorString = attachmentDescriptor?attachmentDescriptor.UTF8String:"";
    string attribsString = attribs.UTF8String;
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    
    std::unique_ptr<std::list<std::unique_ptr<PreparedMessageData> > > r;
    int32_t result;
    r = app->prepareMessageNormal(messageDescriptorString, attachmentDescriptorString, attribsString, 0, &result);
    
    while (!r->empty()) {
        std::unique_ptr<PreparedMessageData> resultStr = move(r->front());
        uint64_t transportId = resultStr->transportId;
        string receiverInfoStr = resultStr->receiverInfo;
        
        NSString *receiverInfo = [NSString stringWithFormat:@"%s",receiverInfoStr.c_str()];
        NSArray *receiverInfoArray = [receiverInfo componentsSeparatedByString:@":"];
        
        NSString *deviceName = @"";
        NSString *deviceId = @"";
        NSString *msgState = @"";
        
        if (receiverInfoArray.count == 4)
        {
            deviceName = receiverInfoArray[1];
            deviceId = receiverInfoArray[2];
            msgState = receiverInfoArray[3];
        }
        
        
        NSDictionary *deviceInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%llu",transportId],@"transportId",
                                    deviceName,@"deviceName",
                                    msgState,@"msgState",
                                    deviceId,@"deviceId",
                                    nil];
        [messageData addObject:deviceInfo];
        
        r->erase(r->begin());
    }
    
    return [messageData copy];
}

-(ChatObject *) updateMessageStatusForChatObject:(ChatObject *) chatObject userData:(NSDictionary *) userData attribs:( NSDictionary *) attribs
{
    BOOL isSync = NO;
    if ([[attribs objectForKey:@"syc"] isEqualToString:@"om"])
    {
        isSync = YES;
    }
    /*
     For sync messages there is not preparedMessageData assigned when they are received
     so create it here
     */
    if (isSync && !chatObject.preparedMessageData)
    {
        NSDictionary *messageDict = [ChatManager formatMessageDescriptorsAndAttribsForChatObject:chatObject sendToMyDevices:NO];
        NSString *json = [messageDict objectForKey:@"messageDescriptor"];
        NSString *attachmentJSON = [messageDict objectForKey:@"attachmentDescriptor"];
        NSString *attribs = [messageDict objectForKey:@"attribs"];
        chatObject.preparedMessageData = [[DBManager dBManagerInstance] getPreparedMessageData:json attachmentDescriptor:attachmentJSON attribs:[NSString stringWithFormat:@"%s",attribs.UTF8String]];
    }
    
    NSString *deviceId = [userData objectForKey:@"scClientDevId"];
    NSMutableArray *preparedMessageData = [chatObject.preparedMessageData mutableCopy];
    
    
    NSString *cmd = [attribs objectForKey:@"cmd"];
    scsMessageStatus status = Sent;
    if ([cmd isEqualToString:@"rr"])
    {
        status = Read;
    }else if ([cmd isEqualToString:@"dr"])
    {
        status = Delivered;
    } else if([cmd isEqualToString:@"failed"])
    {
        status = Failed;
    }
    
    int replacedIndex = 0;
    for (int i = 0; i < preparedMessageData.count; i++)
    {
        NSDictionary *info = preparedMessageData[i];
        NSString *storedDeviceId = [info objectForKey:@"deviceId"];
        if ([deviceId isEqualToString:storedDeviceId])
        {
            replacedIndex = i;
            break;
        }
    }
    NSMutableDictionary *editedInfo = [NSMutableDictionary new];
    if (preparedMessageData.count > 0)
    {
        editedInfo = [preparedMessageData[replacedIndex] mutableCopy];
    }
    [editedInfo setObject:[NSString stringWithFormat:@"%lu",(unsigned long)status] forKey:@"msgState"];
    preparedMessageData[replacedIndex] = editedInfo;
    
    chatObject.preparedMessageData = preparedMessageData;
    
    return chatObject;
}
@end
