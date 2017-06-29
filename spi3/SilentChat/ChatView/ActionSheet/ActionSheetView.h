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
/**
 * ActionSheetView
 **/
#import <AddressBookUI/AddressBookUI.h>
#import <UIKit/UIKit.h>

#import "MessageBurnSliderView.h"
#import "SilentContactsViewController.h"
#import "VoiceRecorderView.h"

@class SCAttachment;

@protocol ActionSheetDelegate<NSObject>
@required
//-(void) sendImageMessage:(UIImage*) image;
- (void)sendMessageWithAssetInfo:(NSDictionary *)assetInfo;
- (void)sendMessageWithAttachment:(SCAttachment *)attachment;
//-(void) sendUserLocation;
@optional
- (void) resignFirstResponderForAction;
@end

@interface ActionSheetView : UIView<UIActionSheetDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate,ABPeoplePickerNavigationControllerDelegate, BurnSliderDelegate,
	VoiceRecorderViewDelegate>

-(void) updateButtonImages;

@property (nonatomic, assign) id <ActionSheetDelegate> delegate;

// Reference to Burn Time Slider View
@property (nonatomic, strong) MessageBurnSliderView *sliderView;

// custom initializer to get Viewcontroller on which ActinSheet is initialized
- (id)initWithFrame:(CGRect)frame forViewController:(UIViewController<SilentContactsViewControllerDelegate>*) viewC;

@property (strong, nonatomic) ABPeoplePickerNavigationController *peoplePicker;

@property (nonatomic, strong) UIPopoverController *popOver;
@end