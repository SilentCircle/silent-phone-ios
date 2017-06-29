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

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>

#import "VoiceRecorderView.h"


@class SCAttachment;


@protocol ActionSheetDelegate<NSObject>
@required
//-(void) sendImageMessage:(UIImage*) image;
- (void)sendMessageWithAssetInfo:(NSDictionary *)assetInfo;
- (void)sendMessageWithAttachment:(SCAttachment *)attachment;
-(void) didTapActionSheetButton;
//-(void) sendUserLocation;
@optional
- (void) resignFirstResponderForAction;
@end

@interface ActionSheetViewRed : UIView <UIActionSheetDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate,
VoiceRecorderViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIViewController *parentViewController;
@property (nonatomic, strong) UIImagePickerController *imagePickerController;

@property (nonatomic, assign) id <ActionSheetDelegate> delegate;
//@property (nonatomic, strong) UIPopoverController *popOver;

@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *actionsheetButtonsArray;


// Location varibles from ActionSheetButtonRed class
@property (weak, nonatomic) IBOutlet UIImageView *locationButtontitleImageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *locationButtonHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *locationButtonWidth;

// 0 - no location, 1 - location on, -1 - location off
@property int locationStatus;
-(void) updateButtonImages;

-(void) didChangeLocationAuthorizationStatus;


@end
