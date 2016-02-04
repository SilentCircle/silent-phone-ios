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
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//#import "UserContact.h"
#import "SCAttachment.h"

@class UserContact;


@interface ChatObject : NSObject
// contact
@property (nonatomic, strong) UserContact *contact;
@property (nonatomic,strong) UIImage *contactImageInVcard;
@property (nonatomic,strong) UIImage *image;
@property (nonatomic, strong) UIImage *imageThumbnail;

// attachments
// name of attachment if exists
// value is null if message doesnt contain attachment
@property (nonatomic, strong) NSString *attachmentName;
@property (nonatomic, strong) SCAttachment *attachment;

@property (nonatomic, strong,setter=setContactName:) NSString *contactName;
@property (nonatomic, strong,setter=setmessageText:) NSString *messageText;

@property (nonatomic, strong/*,setter=setContentRectValue:*/) NSValue *contentRectValue;

@property (nonatomic, strong) NSString *contentRectValueString;

@property (nonatomic,strong,setter=setmsgId:) NSString *msgId;

// check if mapview is rendered and set as image
@property BOOL isLocationImageSet;

// 0 if message is sent, 1 if received
@property (nonatomic,setter=setIsReceived:)int isReceived;

// primary ID key in database
@property (nonatomic,setter=setID:)long ID;

@property (nonatomic,setter=setMessageIdentifier:) long long messageIdentifier;

@property (nonatomic,setter=setMEssageStatus:)long messageStatus;

// if message has been read
// 0 - message is received and hasnt been read
// 1 - message has been read
@property (nonatomic,setter=setIsRead:) int isRead;

@property (nonatomic, strong, setter = setLocation:) CLLocation *location;

@property (nonatomic, setter=setUnixTimeStamp:)long unixTimeStamp;

@property (nonatomic, strong) NSString *displayName;

@property (nonatomic, setter = setBurnTime:) long burnTime;

@property (nonatomic, setter = setUnixReadTimeStamp:) long unixReadTimeStamp;

@property (nonatomic) BOOL isSynced;

@property (nonatomic, strong) NSString *errorString;

@property BOOL isAudioAttachment;

@property (nonatomic, readonly, getter=getIsFailed) BOOL isFailed;

// initializers
-(id) initWithText:(NSString*) text;
-(id) initWithImage:(UIImage*) image;
-(id) initWithAttachment:(SCAttachment *)attachment;

-(void) takeTimeStamp;

-(void)checkWaveFormWithColor:(UIColor *) waveFormColor;

- (void)deleteAttachment;

@property (nonatomic, strong) NSString *audioLength;

@property (nonatomic) int iSendingNow;// do not store it we are setting shis when calling axo->send()
@property (nonatomic) int iDidBurnAnimation;
@property (nonatomic) int burnNow;

@property (nonatomic, strong) NSMutableDictionary *dictionary;

@property (nonatomic, strong) NSTimer *burnTimer;

@property BOOL didPlaySentSound;

@property struct timeval timeVal;

@property (nonatomic) int hasFailedAttachment;
@property (nonatomic) BOOL didTryDownloadTOC;

//This BOOL prevents automatic resend the message many times
//it is not nessary to store this BOOL into DB
@property BOOL didResendMessageAfterRescan;

@end
