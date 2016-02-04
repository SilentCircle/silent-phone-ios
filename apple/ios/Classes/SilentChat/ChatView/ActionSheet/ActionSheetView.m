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
#import "ActionSheetView.h"
#import "ActionSheetButton.h"
#import "LocationManager.h"
#import "MessageBurnSliderView.h"
#import "Utilities.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define kActionSheetHeight 40
#define kImageChatBubbleHeight 200

typedef NS_ENUM(NSInteger, SCLocationTimeType) {
    kSCLocationTimeStopSharing,
    kSCLocationTimeShareOneHour,
    kSCLocationTimeShareOneDay,
    kSCLocationTimeShareIndefinitely
};

@implementation ActionSheetView {
    
    NSArray *actionSheetimages;
    NSArray *actionSheetimagesActive;
    
    // reference to viewcontroller of this ActionSheet
    UIViewController<SilentContactsViewControllerDelegate> *parentViewController;
    
    int clickedActionSheetButtonindex;
    
    NSMutableArray *actionSheetButtons;
}

#pragma mark - View Lifecycle

- (id)initWithFrame:(CGRect)frame forViewController:(UIViewController<SilentContactsViewControllerDelegate>*) viewC {
    
    if (self = [super initWithFrame:frame]) {
        
        // if location is turned on, schedule button image update when location time runs out
        [self updateLocationButtonAfterTimer];
        
        parentViewController = viewC;
        actionSheetimages = [[NSArray alloc] initWithObjects:
                             [UIImage imageNamed:@"PaperClip.png"],
                             [UIImage imageNamed:@"CameraOff.png"],
                             [UIImage imageNamed:@"MicrophoneOff.png"],
                             [UIImage imageNamed:@"BurnOff.png"],
                             [UIImage imageNamed:@"LocationOff.png"],
                             nil];
        
        actionSheetimagesActive = [[NSArray alloc] initWithObjects:
                                   [UIImage imageNamed:@"PaperClip.png"],
                                   [UIImage imageNamed:@"CameraOff.png"],
                                   [UIImage imageNamed:@"MicrophoneOff.png"],
                                   [UIImage imageNamed:@"BurnOn.png"],
                                   [UIImage imageNamed:@"LocationOn.png"],
                                   nil];
        
        actionSheetButtons = [[NSMutableArray alloc] init];
        //🔥📷🎤
        // gray transparent background
        UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, self.frame.size.height)];
        //[backgroundView setAlpha:0.4f];
        [backgroundView setBackgroundColor:[UIColor blackColor]];
        [self addSubview:backgroundView];
        
        // add 6 buttons
        int xoffset = [Utilities utilitiesInstance].screenWidth/5 - self.frame.size.height;
        xoffset = xoffset/2;
        for (int i = 0; i < 5; i ++) {
            ActionSheetButton *actionSheetButton = [[ActionSheetButton alloc] initWithFrame:CGRectMake(xoffset, self.frame.size.height/2 - self.frame.size.height/4 , self.frame.size.height/2, self.frame.size.height/2)];
            actionSheetButton.tag = i;
            [actionSheetButton addTarget:self action:@selector(actionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
            [actionSheetButton.imageView setContentMode:UIViewContentModeScaleAspectFit];
            [actionSheetButton setUserInteractionEnabled:YES];
            [self addSubview:actionSheetButton];
            xoffset += [Utilities utilitiesInstance].screenWidth/5;
            [actionSheetButtons addObject:actionSheetButton];
        }
        [self updateButtonImages];
        
        // observe ActionSheetView.frame
        // whenever frame changes, change any other views frame accordingly
        [self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionOld context:NULL];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if([keyPath isEqualToString:@"frame"]) {
        
        CGRect changedFrame = CGRectZero;
        
        if([object valueForKeyPath:keyPath] != [NSNull null]) {
            changedFrame = [[object valueForKeyPath:keyPath] CGRectValue];
        }
        
        if(_sliderView) {
            [_sliderView setFrame:CGRectMake(0, changedFrame.origin.y - kActionSheetHeight, [Utilities utilitiesInstance].screenWidth,kActionSheetHeight)];
        }
    }
}

-(void)dealloc {
    
    [self removeObserver:self forKeyPath:@"frame"];
}

#pragma mark - Custom

/**
 Click on ActionSheeView buttons
 **/
-(void) actionButtonClick:(UIButton*)button {
    
    clickedActionSheetButtonindex = (int)button.tag;
    
    switch (clickedActionSheetButtonindex) {
            
        case 0: {
            
            // Send photo/video or contact

            UIAlertController *sendFileController = [UIAlertController alertControllerWithTitle:@"Send File From"
                                                                                        message:nil
                                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *photoLibraryAction = [UIAlertAction actionWithTitle:@"Photo Library"
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction *action) { [self showPhotoLibrary]; }];
            [sendFileController addAction:photoLibraryAction];
            
            UIAlertAction *contactsAction = [UIAlertAction actionWithTitle:@"Contacts"
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction *action) { [self showContacts]; }];
            
            [sendFileController addAction:contactsAction];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil)
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:nil];
            
            [sendFileController addAction:cancelAction];
            
            sendFileController.popoverPresentationController.sourceView = parentViewController.view;
            sendFileController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(parentViewController.view.bounds), CGRectGetMidY(parentViewController.view.bounds), 0, 0);
            [sendFileController.popoverPresentationController setPermittedArrowDirections:0];
            [parentViewController presentViewController:sendFileController animated:YES completion:nil];
        }
        break;
            
        case 1: {
            
            // Take photo/video

            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                
                UIImagePickerController *imagePicker = [[UIImagePickerController alloc]init];
                imagePicker.delegate = self;
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                imagePicker.mediaTypes = [NSArray arrayWithObjects:(NSString *)kUTTypeMovie, (NSString *)kUTTypeImage, nil];
                imagePicker.allowsEditing = NO;
                [parentViewController presentViewController:imagePicker animated:YES completion:nil];
            
            } else {
                
                UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Camera Unavailable"
                                                               message:@"Unable to find a camera on your device."
                                                              delegate:nil
                                                     cancelButtonTitle:@"OK"
                                                     otherButtonTitles:nil, nil];
                [alert show];
                alert = nil;
            }
        }
        break;
            
        case 2: {
            
            // Record voice memo

            [self.delegate resignFirstResponderForAction];
			VoiceRecorderView *recordView = [[VoiceRecorderView alloc] init];
			recordView.delegate = self;
			recordView.needsThumbNail = YES;
			[recordView unfurlOnView:parentViewController.view
								 atPoint:CGPointMake(0, 0)];
		}
        break;
            
        case 3: {
            
            // Show Burn Slider
            
            // frame above actionsheet
            if(!_sliderView) {
                
                CGRect sliderViewFrame = CGRectMake(0, self.frame.origin.y - kActionSheetHeight, [Utilities utilitiesInstance].screenWidth, kActionSheetHeight);
                _sliderView = [[MessageBurnSliderView alloc] initWithFrame:sliderViewFrame];
                _sliderView.burnSliderDelegate = self;
                
                // not a good thing to do, but it works
                _sliderView.delegate = (id<MessageBurnSliderTouchDelegate>)parentViewController;
                
                [parentViewController.view addSubview:_sliderView];
                
            } else {
                
                // check if hidden or not
                if(_sliderView.isHidden) {
                    
                    [_sliderView setHidden:NO];
                    
                } else {
                    
                    [_sliderView setHidden:YES];
                }
            }
        }
        break;
            
        case 4: {
            
            // Send Location

            UIAlertController *shareLocationController = [UIAlertController alertControllerWithTitle:@"Share My Location"
                                                                                             message:nil
                                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *oneHourShareAction = [UIAlertAction actionWithTitle:@"Share for One Hour"
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareOneHour]; }];
            [shareLocationController addAction:oneHourShareAction];
            
            UIAlertAction *oneDayShareAction = [UIAlertAction actionWithTitle:@"Share for One Day"
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareOneDay]; }];
            [shareLocationController addAction:oneDayShareAction];

            UIAlertAction *indefintelyShareAction = [UIAlertAction actionWithTitle:@"Share Indefinitely"
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareIndefinitely]; }];
            [shareLocationController addAction:indefintelyShareAction];

            if([Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > 0) {
                
                UIAlertAction *stopSharingAction = [UIAlertAction actionWithTitle:@"Stop sharing my location"
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeStopSharing]; }];
                [shareLocationController addAction:stopSharingAction];
            }
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:nil];
            
            [shareLocationController addAction:cancelAction];
            
            [parentViewController presentViewController:shareLocationController animated:YES completion:nil];
        }
        break;
            
        default:
            break;
    }
}

- (void)showPhotoLibrary {

    if (_popOver) {
        [_popOver dismissPopoverAnimated:NO];
    }
    
    UIImagePickerController *imagePickerController = [UIImagePickerController new];
    [imagePickerController setDelegate:self];
    [imagePickerController setAllowsEditing:NO];
    
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
        [imagePickerController setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    else
        [imagePickerController setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    
    [imagePickerController setMediaTypes:[UIImagePickerController availableMediaTypesForSourceType:imagePickerController.sourceType]];
    
    [parentViewController presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)showContacts {
    
    UIStoryboard *contactsStoryboard = [UIStoryboard storyboardWithName:@"Contacts" bundle:nil];
    SilentContactsViewController *contactsViewController = (SilentContactsViewController*)[contactsStoryboard instantiateViewControllerWithIdentifier:@"ContactsViewController"];
    [contactsViewController setSilentContactsDelegate:parentViewController];
    [contactsViewController setHidesBottomBarWhenPushed:YES];
    [contactsViewController setPresentModally:YES];
    
    [parentViewController.navigationController pushViewController:contactsViewController animated:YES];
}


- (void)updateLocationSharingWithTime:(SCLocationTimeType)locationTimeType {
    
    // Get location when user opens this view
    [[LocationManager locationManagerInstance].locationManager startUpdatingLocation];
    
    switch (locationTimeType) {
            
        case kSCLocationTimeShareOneHour: {
            
            [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime = time(NULL) + 60 * 60; // share for one hour
            [self updateButtonImages];
            [self updateLocationButtonAfterTimer];
        }
            break;
            
        case kSCLocationTimeShareOneDay: {
            
            [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime = time(NULL) + 60 * 60 * 24; // share for one day
            [self updateButtonImages];
            [self updateLocationButtonAfterTimer];
        }
            break;
            
        case kSCLocationTimeShareIndefinitely: {
            
            [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime = time(NULL) + 60 * 60 * 24 * 365; // share indefinitely
            [self updateButtonImages];
        }
            break;
            
        case kSCLocationTimeStopSharing: {
            
            [Utilities utilitiesInstance].selectedRecentObject.shareLocationTime = 0; // stop sharing
            [self updateButtonImages];
        }
            break;
    }
}


-(void) updateLocationButtonAfterTimer {
    
    if([Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL)) {
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateButtonImages) object:nil];
        [self performSelector:@selector(updateButtonImages) withObject:nil afterDelay:[Utilities utilitiesInstance].selectedRecentObject.shareLocationTime - time(NULL)];
    }
}

-(void) updateButtonImages {
    
    for (UIButton *button in actionSheetButtons) {
        
        switch (button.tag) {
                
            case 3: {
                
                if ([Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration > 0)
                    [button setImage:actionSheetimagesActive[button.tag] forState:0];
                else
                    [button setImage:actionSheetimages[button.tag] forState:0];
            }
            break;
                
            case 4: {
                
                if([Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
                    [button setImage:actionSheetimagesActive[button.tag] forState:0];
                else {
                    
                    [[LocationManager locationManagerInstance].locationManager stopMonitoringSignificantLocationChanges];
                    [[LocationManager locationManagerInstance].locationManager stopUpdatingLocation];
                    [button setImage:actionSheetimages[button.tag] forState:0];
                }
            }
            break;
                
            default: {
                [button setImage:actionSheetimages[button.tag] forState:0];
            }
            break;
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    //UIImage *originalImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    //NSString *imageName = [info objectForKey:UIImagePickerControllerReferenceURL];
    //[originalImage setAccessibilityIdentifier:imageName];
    
    if ([self.delegate respondsToSelector:@selector(sendMessageWithAssetInfo:)]) {
        [self.delegate sendMessageWithAssetInfo:info];
    }
}

#pragma mark - VoiceRecorderViewDelegate

- (void)voiceRecorderView:(VoiceRecorderView *)voiceRecorderView didFinishRecordingAttachment:(SCAttachment *)attachment error:(NSError *)error {
    
	if (error) {
		// TODO: present UIAlertView
		return;
	}
    
	if ([self.delegate respondsToSelector:@selector(sendMessageWithAttachment:)])
		[self.delegate sendMessageWithAttachment:attachment];
}

#pragma mark - BurnSliderDelegate

-(void)burnSliderValueStatusChanged {
    
    [self updateButtonImages];
}

#pragma mark - ABPeoplePickerNavigationController Delegate


- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    if (_popOver) {
        [_popOver dismissPopoverAnimated:NO];
    }

    [peoplePicker dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
    
	return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
    
    return YES;
}

@end
