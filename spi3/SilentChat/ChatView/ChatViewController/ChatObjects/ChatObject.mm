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

#import "ChatObject.h"
#import "ChatUtilities.h"
#import "SCAttachment.h"
#import "SCFileManager.h"
#import "SCPCall.h"
#import "SnippetGraphView.h"
#import "AddressBookContact.h"
#import "DBManager.h"

NSString * const kTypeAudio = @"audio/";
NSString * const kTypeApplicationOgg = @"application/ogg";

@implementation ChatObject

-(id) init
{
    if(self = [super init])
    {
        
        _dictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id) initWithCall {
    
    if(self = [super init]) {
        
        _dictionary = [[NSMutableDictionary alloc] init];
        _calls = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(id) initWithText:(NSString*) text
{
    if(self = [self init])
    {
        self.messageText = text;
    }
    
    return self;
}

-(void) takeTimeStamp
{

   //this would be wrong for received messages or we have to remember receive timestamp
   //if we do set it the recv time would be the same as composed timestamp
      // self.unixTimeStamp = _timeVal.tv_sec;

   self.unixTimeStamp = time(NULL);

   

}

-(id) initWithAttachmentFromNetwork:(SCAttachment *)attachment {
   if(self = [self init])
   {
      self.attachment = attachment;
      //must not load thumbnail here

      _messageText = @"";

   }
   return self;
}

-(id) initWithAttachment:(SCAttachment *)attachment {
    if(self = [self init])
    {
        self.attachment = attachment;
        self.imageThumbnail = [attachment thumbnailImage];
        // set empty text, so TableViewController could seperate between text or image
        _messageText = @"";
        //[self takeTimeStamp];
    }
    return self;
}

-(BOOL)mustRemoveFromDB
{
    if (self.isGroupChatObject)
    {
        if (self.isInvitationChatObject == 1)
        {
            return NO;
        }
        return _burnTime + self.unixCreationTimeStamp < time(NULL);
    } else
    {
        return _burnTime && _unixReadTimeStamp && _burnTime + _unixReadTimeStamp < time(NULL);
    }
}

-(void)checkWaveFormWithColor:(UIColor *) waveFormColor{
    if(!_attachment || !_attachment.metadata )return;
    

    NSString *waveForm = [_attachment.metadata objectForKey:@"Waveform"];
    
    NSString *mimeType = [_attachment.metadata objectForKey:@"MimeType"];
    if(waveForm)
    {
        _isAudioAttachment = YES;
        _containsWaveForm = YES;
        NSData *waveFormData = [[NSData alloc] initWithBase64EncodedString:waveForm options:0];
        NSString *waveDuration = [_attachment.metadata objectForKey:@"Duration"];
        const int kMinBurnLocationImageW = 40;
        self.imageThumbnail = [SnippetGraphView thumbnailImageForWaveForm:waveFormData duration:[NSNumber numberWithDouble:waveDuration.doubleValue] frameSize:CGSizeMake([ChatUtilities utilitiesInstance].screenWidth/3*2 - kMinBurnLocationImageW, 40) color:waveFormColor];
        if (waveDuration) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"mmss"
                                                                   options:0
                                                                    locale:[NSLocale currentLocale]];
            formatter.locale = [NSLocale currentLocale];
            formatter.calendar = [ChatUtilities utilitiesInstance].gregorianCalendar;
            _audioLength = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: waveDuration.doubleValue]];
        }
    } else if([mimeType rangeOfString:kTypeAudio].location != NSNotFound || [mimeType isEqualToString:kTypeApplicationOgg]) // audio attachments received from android doesn't contain waveform
    {
        _isAudioAttachment = YES;
        _containsWaveForm = NO;
    }
    
}

-(NSURL *)getAttactmentFileURL{
   
    NSURL *chatDirURL = [SCFileManager chatDirectoryURL];
    
   if(self.attachmentName==nil || self.attachmentName.length < 1){
      
      NSDate *currentTime = [NSDate date];
      
      NSString *an = [NSString stringWithFormat:@"%@-%ld",self.msgId, (unsigned long)[currentTime timeIntervalSince1970]];
      self.attachmentName = [an stringByReplacingOccurrencesOfString:@" " withString:@""];
   }
   
    NSString *fn = [NSString stringWithFormat:@"/%@.sc", self.attachmentName];
    NSURL *pathURL = [chatDirURL URLByAppendingPathComponent:fn];
    
    return pathURL;
}

-(void)saveAttachment{
   //TODO fix if this does not change do not re-write it

   NSURL *fileURL = [self getAttactmentFileURL];   
   [self.attachment writeToFileURL:fileURL atomically:YES];
}

-(void)deleteAttachmentFile{
   if(_attachmentName && _attachmentName.length>1){
       NSURL *fileURL = [self getAttactmentFileURL];
       [SCFileManager deleteFileAtURL:fileURL];
       self.attachmentName = nil;
   }
}

- (void)deleteAttachment {
	if (!_attachment)
		return;
   [self deleteAttachmentFile];
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:_attachment.cloudLocator keyString:_attachment.cloudKey fyeo:NO segmentList:_attachment.segmentList];
	[scloud clearCache];
}

#pragma mark setters for properties
-(void)setmessageText:(NSString *)messageText
{
    _messageText = messageText;
    if (messageText)
        [_dictionary setObject:messageText forKey:@"messageText"];
}

-(void)setContactName:(NSString *)contactName
{
    _localContactName = [[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES];
    
    if (_localContactName)
        [_dictionary setObject:_localContactName forKey:@"contactName"];
}

-(void)setGrpId:(NSString *)grpId
{
    self.senderId = _localContactName;
    _grpId = grpId;
    if (grpId)
        [_dictionary setObject:grpId forKey:@"grpId"];
}

-(void)setSenderId:(NSString *)senderId
{
    _senderId = senderId;
    if (senderId)
        [_dictionary setObject:senderId forKey:@"senderId"];
}

-(void)setDisplayName:(NSString *)displayName
{
    _displayName = displayName;
    if (displayName)
        [_dictionary setObject:displayName forKey:@"displayName"];
}

-(void)setSenderDisplayName:(NSString *)senderDisplayName
{
    _senderDisplayName = senderDisplayName;
    if (senderDisplayName)
        [_dictionary setObject:senderDisplayName forKey:@"senderDisplayName"];
}

-(void)setIsGroupChatObject:(int)isGroupChatObject
{
    _isGroupChatObject = isGroupChatObject;
    [_dictionary setObject:[NSString stringWithFormat:@"%i",isGroupChatObject] forKey:@"isGroupChatObject"];
}

-(void)setIsInvitationChatObject:(int)isInvitationChatObject
{
    _isInvitationChatObject = isInvitationChatObject;
    [_dictionary setObject:[NSString stringWithFormat:@"%i",isInvitationChatObject] forKey:@"isInvitationChatObject"];
}
/*
 -(void)setContentRectValue:(NSValue *)contentRectValue
 {
 _contentRectValue = contentRectValue;
 
 NSString *frameString = NSStringFromCGRect(contentRectValue.CGRectValue);
 
 [_dictionary setValue:frameString forKey:@"contentRectValue"];
 }*/

-(void)setHasFailedAttachment:(int)hasFailedAttachment
{
    _hasFailedAttachment = hasFailedAttachment;
    if(hasFailedAttachment == 1)
    {
        if(_isReceived == 1)
        {
            self.imageThumbnail = [UIImage imageNamed:@"recivedFileError.png"];
        }
    }
    
    [_dictionary setObject:[NSString stringWithFormat:@"%i",_hasFailedAttachment] forKey:@"hasFailedAttachment"];
    
}

-(void)setUnixDeliveryTimeStamp:(long)unixTimeStamp
{
    if (unixTimeStamp + 60  > time(NULL))
    {
        unixTimeStamp = time(NULL);
    }
   _unixDeliveryTimeStamp = unixTimeStamp;
   [_dictionary setObject:[NSString stringWithFormat:@"%li",unixTimeStamp] forKey:@"unixDeliveryTimeStamp"];
}

-(void)setSendersDevID:(NSString *)ns{
   _sendersDevID = ns;
    if (ns)
        [_dictionary setObject:ns forKey:@"sendersDevID"];
}

-(void)setUnixTimeStamp:(long)unixTimeStamp
{
    _unixTimeStamp = unixTimeStamp;
    [_dictionary setObject:[NSString stringWithFormat:@"%li",unixTimeStamp] forKey:@"unixTimeStamp"];
}

-(BOOL)getIsAttachment{
   return _attachment ? YES : NO;
}

-(int)getISendingNow{
   return [[DBManager dBManagerInstance]isSendingNowChatObject:self];
}

-(void)setISendingNow:(int)iSendingNow{
   [[DBManager dBManagerInstance] markAsSendingChatObject:self mark:iSendingNow?YES:NO];
}

-(NSString *)getContactName
{
    if (_grpId)
    {
        return _grpId;
    }
    return _localContactName;
}

-(BOOL)getIsFailed
{
    if(_isReceived==1 || _isSynced){
        return NO;
    }
    if(_messageIdentifier == 0 && self.iSendingNow == 0)
    {
        return YES;
    }
    else if(_messageIdentifier != 0  && (_messageStatus < 0 || _messageStatus >= 400))
    {
        return YES;
    }
    return NO;
}

-(void)setIsReceived:(int)isReceived
{
    _isReceived = isReceived;
    if(_attachment)
    {
        if(isReceived == 1)
        {
            [self checkWaveFormWithColor:[UIColor blackColor]];
        }
        else
        {
            [self checkWaveFormWithColor:[UIColor blackColor]];
        }
    }
    [_dictionary setObject:[NSString stringWithFormat:@"%i",isReceived] forKey:@"isReceived"];
}

-(void)setIsStoredAfterDeletion:(int)isStoredAfterDeletion
{
   if(isStoredAfterDeletion){
      [self deleteAttachment];
       self.messageText = @"";
    }
    _isStoredAfterDeletion = isStoredAfterDeletion;
    [_dictionary setObject:@"1" forKey:@"isStoredAfterDeletion"];
}

-(void)setErrorString:(NSString *)errorString
{
    _errorString = errorString;
    if (errorString)
        [_dictionary setObject:errorString forKey:@"errorString"];
}
-(void)setErrorStringExistingMsg:(NSString *)errorStringExistingMsg
{
   _errorStringExistingMsg = errorStringExistingMsg;
    if (errorStringExistingMsg)
        [_dictionary setObject:errorStringExistingMsg forKey:@"errorStringExistingMsg"];
}


-(void)setCallState:(int)callState
{
    _callState = callState;
    
    [_dictionary setObject:[NSString stringWithFormat:@"%i",callState] forKey:@"callState"];
}

-(void)setID:(long)ID
{
    _ID = ID;
    [_dictionary setObject:[NSString stringWithFormat:@"%li",ID] forKey:@"ID"];
}

-(void)setMessageIdentifier:(long long)messageIdentifier
{
    _messageIdentifier = messageIdentifier;
    [_dictionary setObject:[NSString stringWithFormat:@"%lli",messageIdentifier] forKey:@"messageIdentifier"];
    
}

-(void)setIsSynced:(BOOL)isSynced
{
    _isSynced = isSynced;
    [_dictionary setObject:[NSNumber numberWithBool:isSynced] forKey:@"isSynced"];
}
-(void)setIsCall:(BOOL)isCall
{
    _isCall = isCall;
    [_dictionary setObject:[NSNumber numberWithBool:isCall] forKey:@"isCall"];
}
-(void)setIsIncomingCall:(int)isIncomingCall
{
    _isIncomingCall = isIncomingCall;
     [_dictionary setObject:[NSNumber numberWithInteger:isIncomingCall] forKey:@"isIncomingCall"];
}

- (void)setCallDuration:(time_t)dur
{
    _callDuration = dur;
    [_dictionary setObject:@(_callDuration) forKey:@"callDuration"];
}

-(void)setMessageStatus:(long long)messageStatus
{
    _messageStatus = messageStatus;
    [_dictionary setObject:[NSString stringWithFormat:@"%lli",messageStatus] forKey:@"messageStatus"];
}

-(void)setDelivered:(BOOL)delivered{
   _delivered = delivered;
   [_dictionary setObject:[NSNumber numberWithBool:delivered] forKey:@"delivered"];
}

-(void)setIsRead:(int)isRead
{
    if(isRead == 1 && !self.unixReadTimeStamp){
        self.unixReadTimeStamp = time(NULL);
    }
    _isRead = isRead;
    [_dictionary setObject:[NSString stringWithFormat:@"%i",isRead] forKey:@"isRead"];
    
}
-(void)setMustSendRead:(BOOL)mustSendRead{
   _mustSendRead = mustSendRead;
    [_dictionary setObject:[NSString stringWithFormat:@"%i",mustSendRead] forKey:@"mustSendRead"];
   
}

-(void) setUnixReadTimeStamp:(long long) unixTimeStamp
{
    _unixReadTimeStamp = unixTimeStamp;
    [_dictionary setObject:[NSString stringWithFormat:@"%lli",unixTimeStamp] forKey:@"unixReadTimeStamp"];
}

-(long long)getUnixCreationTimeStamp
{
    return self.timeVal.tv_sec;
}



-(void)setBurnTime:(long)burnTime
{
    _burnTime = burnTime;
    [_dictionary setObject:[NSString stringWithFormat:@"%li",burnTime] forKey:@"burnTime"];
}


-(void)setLocation:(CLLocation *)location
{
    _location = location;
    
    NSMutableDictionary *locationDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                               [NSString stringWithFormat:@"%f",location.coordinate.latitude], @"latitude",
                                               [NSString stringWithFormat:@"%f",location.coordinate.longitude],@"longitude",
                                               [NSString stringWithFormat:@"%f",location.altitude], @"altitude",
                                               [NSString stringWithFormat:@"%f",location.horizontalAccuracy], @"horizontalAccuracy",
                                               [NSString stringWithFormat:@"%f",location.verticalAccuracy], @"verticalAccuracy",
                                               nil];
    
    [_dictionary setObject:locationDictionary forKey:@"location"];
}

#if HAS_DATA_RETENTION
- (void)setDREnabled:(BOOL)drEnabled {
    _drEnabled = drEnabled;
    [_dictionary setObject:[NSNumber numberWithBool:drEnabled] forKey:@"drEnabled"];
}
#endif // HAS_DATA_RETENTION

-(void)setmsgId:(NSString *)msgId
{
    _msgId = msgId;
    
    if(_msgId == nil){
        char buf[64];
        CTAxoInterfaceBase::generateMsgID("", buf, sizeof(buf));
        _msgId = [NSString stringWithUTF8String:buf];
    }
    

    if (_msgId)
        [_dictionary setObject:_msgId forKey:@"msgId"];
    
    CTAxoInterfaceBase::uuid_sz_time(_msgId.UTF8String, &_timeVal);
}

-(void)setAttachmentName:(NSString *)attachmentName {

    _attachmentName = attachmentName;
    if(attachmentName==nil){
       [_dictionary removeObjectForKey:@"attachment"];
       return;
    }
    [_dictionary setObject:attachmentName forKey:@"attachment"];
}

-(void)setPreparedMessageData:(NSMutableArray *)preparedMessageData
{
    _preparedMessageData = preparedMessageData;
    if (preparedMessageData)
        [_dictionary setObject:preparedMessageData forKey:@"preparedMessageData"];
}

-(void)setAttachment:(SCAttachment *)attachment {
	_attachment = attachment;
    if (attachment.cloudLocator)
        [_dictionary setObject:attachment.cloudLocator forKey:@"cloudLocator"];
    if (attachment.cloudKey)
        [_dictionary setObject:attachment.cloudKey forKey:@"cloudKey"];
    if (attachment.segmentList)
        [_dictionary setObject:attachment.segmentList forKey:@"segmentList"];
}

-(void)setImageThumbnail:(UIImage *)imageThumbnail {
    
    UIImage * scaledImage = [UIImage alloc];
    _imageThumbnail = [scaledImage initWithCGImage:[imageThumbnail CGImage] scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    
    
    CGSize thumbnailSize = _imageThumbnail.size;
    
    // if we have smaller thumbnail size than min chat bubble size,
    // upscale the size keeping aspect ratio
    _imageThumbnailFrameSize = thumbnailSize;
    
}

-(void) addCall:(SCPCall *) call
{
    if(!_calls)
        return;
    
    //format - unixTimeStamp/duration example 1415463675/5 for a five second call
    // duration can be 0
    NSString *callString = [NSString stringWithFormat:@"%li/%li",time(NULL),time(NULL) - call.startTime];
    
    [_calls addObject:callString];
    _dictionary[@"calls"] = _calls;
}

- (void)cleanTmpFlags{
   _tmpPostStateDidChange = NO;
   _tmpAddToBurn = NO;
   _tmpDownloadTOC = NO;
   _tmpIsNewMsg = NO;
   _tmpAddBadge = NO;
   _tmpRemBadge = NO;
}
@end
