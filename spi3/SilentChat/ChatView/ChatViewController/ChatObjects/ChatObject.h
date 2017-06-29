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

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SCAttachment;
@class SCPCall;
@class AddressBookContact;


@interface ChatObject : NSObject
// contact
@property (nonatomic, strong) AddressBookContact *contact;
@property (nonatomic,strong) UIImage *contactImageInVcard;
@property (nonatomic,strong) UIImage *image;
@property (nonatomic, strong) UIImage *imageThumbnail;

// attachments
// name of attachment if exists
// value is null if message doesnt contain attachment
@property (nonatomic, strong) NSString *attachmentName;
@property (nonatomic, strong) SCAttachment *attachment;


/*
 For group messages contactname getter will return grpid, and messages contactname will be available in senderid
 */
@property (nonatomic, strong,setter=setContactName:,getter=getContactName) NSString *contactName;

@property (nonatomic, strong) NSString * localContactName;

/*
 When setting grpId, this setter will set senderId as contactname and contactname getter will return this value
 */
@property (nonatomic, strong,setter=setGrpId:) NSString *grpId;

@property (nonatomic, strong,setter=setSenderId:) NSString *senderId;

@property (nonatomic, strong,setter=setmessageText:) NSString *messageText;

@property CGSize messageTextViewSize;

@property (nonatomic) CGSize imageThumbnailFrameSize;

@property (nonatomic,strong,setter=setmsgId:) NSString *msgId;

// check if mapview is rendered and set as image
@property BOOL isLocationImageSet;

// 0 if message is sent, 1 if received
@property (nonatomic,setter=setIsReceived:)int isReceived;

// primary ID key in database
@property (nonatomic,setter=setID:)long ID;

@property (nonatomic,setter=setMessageIdentifier:) long long messageIdentifier;

@property (nonatomic,setter=setMessageStatus:)long long messageStatus; //if we have 200 here show the sent state
@property (nonatomic)BOOL delivered;//set this only when we see delivery notif from network

// if message has been read
// 0 - message is received and hasnt been read
// 1 - message has been read
@property (nonatomic,setter=setIsRead:) int isRead;

//TODO set this first and then send message out and send it out from queue (stackedReads)
//the app can crash and we would never send it
@property (nonatomic) BOOL mustSendRead;

@property (nonatomic, strong, setter = setLocation:) CLLocation *location;

@property (nonatomic, setter=setUnixTimeStamp:)long unixTimeStamp;
@property (nonatomic, setter=setUnixDeliveryTimeStamp:)long unixDeliveryTimeStamp;


/*
 In case of group chat object's displayname is group chat's display name 
  and senderDisplayName is sender's displayname
 */
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *senderDisplayName;
@property (nonatomic, strong) NSString *sendersDevID;//only for received messages

@property (nonatomic, setter = setBurnTime:) long burnTime;

// message read time
@property (nonatomic, setter = setUnixReadTimeStamp:) long long unixReadTimeStamp;

// message creation time
// returns timeval.tv_sec value taken from msgid
@property (nonatomic, getter=getUnixCreationTimeStamp) long long unixCreationTimeStamp;

@property (nonatomic) BOOL isSynced;

@property (nonatomic, strong) NSString *errorString;
//we can not save in errorString and have to use errorStringExistingMsg because
//errorString is used as flag in the code, and used to identify to undecrytable messages on local side
//the errorStringExistingMsg is more for a message what we did send out  and a remote pary can not decrypt
@property (nonatomic, strong) NSString *errorStringExistingMsg;


#if HAS_DATA_RETENTION
// data retention enabled
@property (nonatomic, setter = setDREnabled:) BOOL drEnabled;
#endif // HAS_DATA_RETENTION

@property BOOL isAudioAttachment;
@property BOOL containsWaveForm;

@property (nonatomic, readonly, getter=getIsFailed) BOOL isFailed;
@property (nonatomic, readonly, getter=getIsAttachment) BOOL isAttachment;

// initializers
-(id) initWithText:(NSString*) text;
-(id) initWithAttachment:(SCAttachment *)attachment;
-(id) initWithAttachmentFromNetwork:(SCAttachment *)attachment;
-(id) initWithCall;

-(void) takeTimeStamp;

-(void)checkWaveFormWithColor:(UIColor *) waveFormColor;

- (void)deleteAttachment;
-(void)deleteAttachmentFile;
-(void)saveAttachment;

/*
 returns true if messages burn time is in the past
 This is called usually when message is taken out of DB
 
 Always returns NO for group status messages
 
 For group messages uses message creation time + burn time as a time to be in the past
 
 For normal messages if they are unread this will always return NO
 For normal read messages read time +burn time is used to be in the past
 */
-(BOOL)mustRemoveFromDB;

@property (nonatomic, strong) NSString *audioLength;

@property (nonatomic, getter=getISendingNow) int iSendingNow;// do not store it we are setting shis when calling axo->send()
@property (nonatomic) int iDidBurnAnimation;
@property (nonatomic) int burnNow;

@property (nonatomic, strong) NSMutableDictionary *dictionary;

//@property (nonatomic, strong) NSTimer *burnTimer;

@property BOOL didPlaySentSound;

@property struct timeval timeVal;

@property (nonatomic) int hasFailedAttachment;
@property (nonatomic) BOOL didTryDownloadTOC;

//This BOOL prevents automatic resend the message many times
//it is not nessary to store this BOOL into DB
@property BOOL didResendMessageAfterRescan;

//-(void) calculateHeight;


@property (nonatomic, strong) NSMutableArray *calls;
-(void) addCall:(SCPCall *) call;

@property (nonatomic) BOOL  isCall;
// enum CallState, declared in SCPCall.h; set in DBManagerCallDidEnd.
@property (nonatomic) int callState;
@property (nonatomic) time_t callDuration;


// 0 - last call was incoming call
// 1 - last call was outgoing call
@property (nonatomic) int isIncomingCall;

// for burn status sent when device is offline
@property (nonatomic,setter=setIsStoredAfterDeletion:) int isStoredAfterDeletion;

@property BOOL isShowingBurnButton;

//if we do fast load from DB we have to set it
//we have to do tihs because we can not clean up an attachment
@property BOOL halfLoaded;

//when we receive zina msg it happens in two stages
 //1)zina calls storeMsg: and we have save into a msg DB and to return as fast as possible  and set TODO flags
  //2)zina calls recvMsg, exec TODO flags

//temp receive store zina TODO flags
- (void)cleanTmpFlags;

//should we do something like adding blocks(or tasks) to exec into quvue
@property BOOL tmpPostStateDidChange;
@property BOOL tmpAddToBurn;
@property BOOL tmpDownloadTOC;
@property BOOL tmpIsNewMsg;
@property BOOL tmpAddBadge;
@property BOOL tmpRemBadge;



@property (nonatomic,setter=setIsGroupChatObject:) int isGroupChatObject;

// treat this chatobject as accepted or declined invitation chatobject
@property (nonatomic, setter=setIsInvitationChatObject:) int isInvitationChatObject;

/*
 Info for delivered devices for this message
 Contains NSDictionaries with deviceId, transportId and messageStatus
 */
@property (nonatomic, strong,setter=setPreparedMessageData:) NSArray *preparedMessageData;




@end
