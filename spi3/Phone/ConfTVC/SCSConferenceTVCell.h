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
//
//  SCSConferenceTVCell.h
//  SPi3
//
//  Created by Eric Turner on 11/14/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCSContactViewCell.h"
#import "SCSConferenceCellDelegate.h"

@class SCPCall;
@class SCSCallDurationView;

@interface SCSConferenceTVCell : SCSContactViewCell

@property (weak, nonatomic) SCPCall *call;
@property (weak, nonatomic) id<SCSConferenceCellDelegate> delegate;

//----------------------------------------------------------------------
// Inherits SCSContactViewCell SCSContactView/functionality
//----------------------------------------------------------------------
//@property (weak, nonatomic) IBOutlet UILabel *lbAvatarVerify;
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Destination, destination name, call duration
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UILabel *lbDst;             // +1(555)123-4567
@property (weak, nonatomic) IBOutlet UILabel *lbDstName;         //John Carter
// callDurView encapsulates: label (01:59) with update API
@property (weak, nonatomic) IBOutlet SCSCallDurationView *callDurView;
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// ZRTP
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView      *zrtpPanelView;

@property (weak, nonatomic) IBOutlet UILabel     *lbSecure;      // GOING SECURE
//@property (weak, nonatomic) IBOutlet UILabel     *lbSecureSmall; // above verifySAS
@property (weak, nonatomic) IBOutlet UIImageView *ivVerified;    // green checkmark
@property (weak, nonatomic) IBOutlet UIImageView *dataRetentionImageView;

@property (weak, nonatomic) IBOutlet UIView      *sasView;       // rounded view wrapper
@property (weak, nonatomic) IBOutlet UILabel     *lbSAS;         // SAS phrase label

//----------------------------------------------------------------------
// Call buttons
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView      *callButtonsView;
@property (weak, nonatomic) IBOutlet UIButton    *btEndCall;
@property (weak, nonatomic) IBOutlet UIView      *incomingCallButtonsView;
@property (weak, nonatomic) IBOutlet UIButton    *btDeclineCall;
@property (weak, nonatomic) IBOutlet UIButton    *btAnswerCall;
//----------------------------------------------------------------------

@property (assign, nonatomic) BOOL isReordering;


- (void)updateDuration;

@end
