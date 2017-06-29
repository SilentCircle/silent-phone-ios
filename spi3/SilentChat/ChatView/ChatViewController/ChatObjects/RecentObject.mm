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

#import "RecentObject.h"

#import "ChatObject.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "NSDictionaryExtras.h"
#import "SCFileManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCSContactsManager.h"
#import "SPUser.h"
#import "AddressBookContact.h"
#import "GroupChatManager+Members.h"

#import "SCFileManager.h"

@implementation RecentObject {
    
    NSString *_displayAlias;
    NSMutableDictionary *_dictionary;
}

-(instancetype) init {
    
    if(self = [super init]) {
        
        [self initializeVariables];
    }
    
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)jsonDict {
    
    if(self = [super init]) {
        
        [self initializeVariables];
        
        BOOL success = [self updateWithJSON:jsonDict];
        
        if(!success)
            return nil;
    }
    
    return self;
}

- (void)initializeVariables {
    
    _dictionary = [NSMutableDictionary new];
    _conversationImages = [NSMutableDictionary new];
}

- (BOOL)updateWithJSON:(NSDictionary *)jsonDict {

    if(![jsonDict isKindOfClass:[NSDictionary class]])
        return NO;

    if(![jsonDict safeStringForKey:@"uuid"])
        return NO;
    
    if([jsonDict safeStringForKey:@"uuid"])
        self.contactName = [jsonDict safeStringForKey:@"uuid"];
    
    if([jsonDict safeStringForKey:@"display_name"])
        self.displayName = [jsonDict safeStringForKey:@"display_name"];
    
    if([jsonDict safeStringForKey:@"display_alias"])
        self.displayAlias = [jsonDict safeStringForKey:@"display_alias"];
    
    if([jsonDict safeStringForKey:@"display_organization"])
        self.displayOrganization = [jsonDict safeStringForKey:@"display_organization"];

    if([jsonDict safeStringForKey:@"avatar_url"])
        self.avatarUrl = [jsonDict safeStringForKey:@"avatar_url"];
    
    //
    // Do not do the image downloading part here
    // as this will block the running thread
    // until the avatar image is downloaded
    // which may take a while.
    // TODO: Move that to when we actually want to show the avatar
    // image (in a cell, on call screen etc)
    //
    //if([jsonDict safeStringForKey:@"avatar_url"]) {
    //    
    //    NSString *avatarURLString = [jsonDict safeStringForKey:@"avatar_url"];
    //    NSURL *avatarURL = [ChatUtilities buildApiURLForPath:avatarURLString];
    //    
    //    SCSContactImageObject *imageObject = [SCSContactImageObject new];
    //    imageObject.recent      = self;
    //    imageObject.contactName = [jsonDict safeStringForKey:@"uuid"];
    //    imageObject.avatarImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:avatarURL]];
    //
    //    [self.conversationImages setObject:imageObject
    //                                forKey:imageObject.contactName];
    //}
    
    return YES;
    
//#if HAS_DATA_RETENTION
//    // NOTE: here we support both the server property names (data_retention) and database property names (drEnabled)
//    NSDictionary *drDict = [jsonDict objectForKey:@"data_retention"];
//    if (drDict) {
//        // this is data from the server
//        self.drOrganization = [drDict safeStringForKey:@"for_org_name"];
//        NSDictionary *retainedDR = [drDict objectForKey:@"retained_data"];
//        self.drTypeCode = [SPUser DRTypeCodeFromDict:retainedDR];
//        self.drEnabled = (self.drTypeCode > 0);
//        if (self.drEnabled)
//            NSLog(@"DR enabled for contact with code = %d", self.drTypeCode);
//
//        self.drBlockCode = 0;
//        NSDictionary *drBlockDict = [drDict objectForKey:@"block_retention_of"];
//        if (drBlockDict)
//            self.drBlockCode = [SPUser DRBlockCodeFromDict:drBlockDict];
//
//    } else {
//        // database properties
//        self.drEnabled = [jsonDict safeBoolForKey:@"drEnabled"];
//        self.drOrganization = [jsonDict safeStringForKey:@"drOrganization"];
//        self.drTypeCode = (uint32_t)[jsonDict safeUnsignedLongForKey:@"drTypeCode"];
//        self.drBlockCode = (uint32_t)[jsonDict safeUnsignedLongForKey:@"drBlockCode"];
//    }
//#endif // HAS_DATA_RETENTION
}

- (NSDictionary *)dictionaryRepresentation {
    
    @synchronized (self) {
        return _dictionary;
    }
}

-(void)setContactName:(NSString *)contactName
{
    _contactName = contactName;
    
    @synchronized (self) {
        
        if (contactName)
            [_dictionary setObject:contactName
                            forKey:@"contactName"];
    }
}

-(void)setDisplayAlias:(NSString *)displayAlias
{
    _displayAlias = displayAlias;
    
    @synchronized (self) {
        
        if (displayAlias)
            [_dictionary setObject:displayAlias
                            forKey:@"displayAlias"];
    }
}

-(void)setDisplayOrganization:(NSString *)displayOrganization
{
    _displayOrganization = displayOrganization;
    
    @synchronized (self) {
        
        if (displayOrganization)
            [_dictionary setObject:displayOrganization
                            forKey:@"displayOrganization"];
    }
}

-(void)setAvatarUrl:(NSString *)avatarUrl {
    
    _avatarUrl = avatarUrl;
    
    @synchronized (self) {
        
        if (avatarUrl)
            [_dictionary setObject:avatarUrl
                            forKey:@"avatarUrl"];
    }
}

-(void)setHasGroupAvatarBeenSetExplicitly:(BOOL)hasGroupAvatarBeenSetExplicitly
{
    _hasGroupAvatarBeenSetExplicitly = hasGroupAvatarBeenSetExplicitly;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%i",hasGroupAvatarBeenSetExplicitly]
                        forKey:@"hasGroupAvatarBeenSetExplicitly"];
    }
}

-(void)setHasGroupNameBeenSetExplicitly:(BOOL)hasGroupNameBeenSetExplicitly
{
    _hasGroupNameBeenSetExplicitly = hasGroupNameBeenSetExplicitly;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%i",hasGroupNameBeenSetExplicitly]
                        forKey:@"hasGroupNameBeenSetExplicitly"];
    }
}

-(NSString *)displayAlias
{
    if(nil == _displayAlias || [_displayAlias isEqualToString:@""])
        return _contactName;
    else
        return _displayAlias;
}

-(void)setUnixTimeStamp:(long)unixTimeStamp
{
    _unixTimeStamp = unixTimeStamp;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%li",unixTimeStamp]
                        forKey:@"unixTimeStamp"];
    }
}

-(void)setBurnDelayTimeOut:(long)burnDelayDuration
{
    _burnDelayDuration = burnDelayDuration;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%li",burnDelayDuration]
                        forKey:@"burnDelayDuration"];
    }
}

-(void)setShareLocationTime:(long)shareLocationTime
{
    _shareLocationTime = shareLocationTime;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%li",shareLocationTime]
                        forKey:@"shareLocationTime"];
    }
}

-(void)sethasBurnBeenSet:(long)hasBurnBeenSet
{
    _hasBurnBeenSet = hasBurnBeenSet;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%ld",hasBurnBeenSet]
                        forKey:@"hasBurnBeenSet"];
    }
}

-(void)setIsGroupRecent:(int)isGroupRecent
{
    _isGroupRecent = isGroupRecent;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSString stringWithFormat:@"%i",isGroupRecent]
                        forKey:@"isGroupRecent"];
    }
}

-(void)setDisplayName:(NSString *)displayName
{
    if (displayName.length > 0) {
        _displayName = displayName;
        
        @synchronized (self) {
            
            [_dictionary setObject:displayName
                            forKey:@"displayName"];
        }
    }
}

#if HAS_DATA_RETENTION
-(void)setDROrganization:(NSString *)drOrganization {
    if (drOrganization.length > 0) {
        _drOrganization = drOrganization;
        
        @synchronized (self) {
            
            [_dictionary setObject:drOrganization
                            forKey:@"drOrganization"];
        }
    }
}

- (void)setDREnabled:(BOOL)drEnabled {
    _drEnabled = drEnabled;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSNumber numberWithBool:drEnabled]
                        forKey:@"drEnabled"];
    }
}

- (void)setDRTypeCode:(uint32_t)drTypeCode {
    _drTypeCode = drTypeCode;
    
    @synchronized (self) {
        
        [_dictionary setObject:[NSNumber numberWithUnsignedLong:drTypeCode]
                        forKey:@"drTypeCode"];
    }
}

- (void)setDRBlockCode:(uint32_t)drBlockCode {
    _drBlockCode = drBlockCode;
    
    @synchronized (self) {

        [_dictionary setObject:[NSNumber numberWithUnsignedLong:drBlockCode]
                        forKey:@"drBlockCode"];
    }
}
#endif // HAS_DATA_RETENTION

- (void)loadLastConversation {
    
    if(self.lastConversationObject)
        return;
    
    self.lastConversationObject = [[DBManager dBManagerInstance] getLastChatObjectForName:self.contactName];
    
    if(self.lastConversationObject)
        self.unixTimeStamp = self.lastConversationObject.unixTimeStamp;
}

- (BOOL)isEqual:(id)object {
    
    if(!object)
        return NO;
    
    if (self == object)
        return YES;
    
    if (![object isKindOfClass:[RecentObject class]])
        return NO;
    
    if(!self.contactName)
        return NO;
    
    RecentObject *otherRecent = (RecentObject *)object;

    if(!otherRecent.contactName)
        return NO;
    
    NSString *cleanedSelfUUID = [[ChatUtilities utilitiesInstance] removePeerInfo:self.contactName
                                                                        lowerCase:NO];
    
    NSString *cleanedOtherUUID = [[ChatUtilities utilitiesInstance] removePeerInfo:otherRecent.contactName
                                                                         lowerCase:NO];

    // If two recent objects have the same uuid, they are the same recent object
    return [cleanedSelfUUID isEqualToString:cleanedOtherUUID];
}

- (void)updateWithRecent:(RecentObject *)recentObject {

    if(![self isEqual:recentObject])
        return;
    
    [self setDisplayName:recentObject.displayName];
    [self setDisplayAlias:recentObject.displayAlias];
    [self setDisplayOrganization:recentObject.displayOrganization];
    [self setAvatarUrl:recentObject.avatarUrl];
    [self setAbContact:recentObject.abContact];
}

- (NSString *)debugDescription {
    
    return [NSString stringWithFormat:@"contactName (uuid): %@ displayName: %@ displayAlias: %@ displayOrganization: %@ avatarUrl: %@ abContact: %@",
            self.contactName,
            self.displayName,
            self.displayAlias,
            self.displayOrganization,
            self.avatarUrl,
            self.abContact];
}

@end
