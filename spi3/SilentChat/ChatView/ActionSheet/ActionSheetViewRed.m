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

#import <MobileCoreServices/MobileCoreServices.h>
#import "ActionSheetViewRed.h"

#import "ChatViewController.h"
#import "ChatUtilities.h"
#import "LocationManager.h"
#import "RecentObject.h"
#import "SendButton.h"
#import "SystemPermissionManager.h"
#import "UserService.h"
#import "DBManager.h"
// Categories
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"
#import <Photos/Photos.h>


#import <Contacts/Contacts.h>
#import "SCPNotificationKeys.h"


typedef NS_ENUM(NSInteger, SCLocationTimeType) {
    kSCLocationTimeStopSharing,
    kSCLocationTimeShareOneHour,
    kSCLocationTimeShareOneDay,
    kSCLocationTimeShareIndefinitely
};

@implementation ActionSheetViewRed
{
    float oldX, oldY;
    BOOL dragging;
    int clickedActionSheetButtonindex;
    
    // selected location time when location is not enabled yet
    // used to set location later when user has given permission
    SCLocationTimeType lastSelectedLocationTimeType;
    BOOL shouldTurnOnLocationAutomaticallyAfterAquiringLocation;
   // NSMutableArray *actionButtonsArray;
}

/*
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    dragging = YES;
    oldX = touchLocation.x;
    oldY = touchLocation.y;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    NSLog(@"here2");
    if (dragging) {
        CGRect frame = self.frame;
        frame.origin.y =  self.frame.origin.y + touchLocation.y - oldY;
        self.frame = frame;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [super touchesEnded:touches withEvent:event];
    dragging = NO;
}*/

/*
-(void) addButtons
{
    int xOffset = 3;
    int yOffset = 0;
    int buttonWidth = self.frame.size.width / 3 - 4;
    
    int buttonHeight = self.frame.size.height / 2 - 4;
    int buttonTag = 0;
    for (int i = 0; i<2; i++) {
        
        for (int j = 0; j<3; j++) {
            ActionSheetButtonRed *actionButton = [[ActionSheetButtonRed alloc] initWithFrame:CGRectMake(xOffset, yOffset, buttonWidth, buttonHeight)];
            
            [actionButton addTarget:self action:@selector(actionButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
            [actionButtonsArray addObject:actionButton];
            xOffset += buttonWidth + 3;
            actionButton.tag = buttonTag;
            actionButton.buttonTag = buttonTag;
            [self addSubview:actionButton];
            buttonTag ++;
        }
        xOffset = 3;
        yOffset += buttonHeight + 3;
    }
}*/

-(IBAction) actionButtonClick:(UIButton*)button {
    
    if ([self.delegate respondsToSelector:@selector(didTapActionSheetButton)])
    {
        [self.delegate didTapActionSheetButton];
    }
        // EA: currently all actions require UserPermission_SendAttachment
        // if that changes, this needs to become more conditional:
        
        // Check if user has permission to upload attachments
        if (![[UserService currentUser] hasPermission:UserPermission_SendAttachment]) {
            
            // off-load to upsell flow
            [[UserService sharedService] upsellPermission:UserPermission_SendAttachment];
            return;
        }

        clickedActionSheetButtonindex = (int)button.tag;
        
        switch (clickedActionSheetButtonindex) {
                
            case 0: {
                
                if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                    
                    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
                    
                    if(status == AVAuthorizationStatusAuthorized) {
                        [self openCamera:(NSString*)kUTTypeImage];
                    }
                    else if(status == AVAuthorizationStatusDenied){
                        [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Camera"];
                        return;
                    }
                    else if(status == AVAuthorizationStatusRestricted){
                        [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Camera"];
                        return;
                        
                    }
                    else if(status == AVAuthorizationStatusNotDetermined){
                        
                        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                            if(granted){
                                [self openCamera:(NSString*)kUTTypeImage];
                            }
                        }];
                    }
                    
                } else {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Camera Unavailable", nil) message:NSLocalizedString(@"Unable to find a camera on your device.", nil) preferredStyle:UIAlertControllerStyleActionSheet];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                    [_parentViewController presentViewController:alert animated:YES completion:nil];
                }
                break;
            }
                
            case 1: {
                
                PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
                if (status == PHAuthorizationStatusAuthorized)
                {
                    [self showPhotoLibrary];
                }
                else if (status == PHAuthorizationStatusDenied)
                {
                    [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Photo library"];
                    return;
                }
                
                else if (status == PHAuthorizationStatusNotDetermined)
                {
                    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                        
                        if (status == PHAuthorizationStatusAuthorized)
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self showPhotoLibrary];
                            });
                        }
                    }];  
                }
                else if (status == PHAuthorizationStatusRestricted)
                {
                    [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Photo library"];
                    return;
                }
                break;
            }
                
            case 2: {
                // send video
                if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                    
                    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
                    
                    if(status == AVAuthorizationStatusAuthorized) {
                        [self openCamera:(NSString*)kUTTypeMovie];
                    }
                    else if(status == AVAuthorizationStatusDenied){
                        [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Camera"];
                        return;
                    }
                    else if(status == AVAuthorizationStatusRestricted){
                        [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Camera"];
                        return;
                        
                    }
                    else if(status == AVAuthorizationStatusNotDetermined){
                        
                        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                            if(granted){
                                [self openCamera:(NSString*)kUTTypeMovie];
                            }
                        }];
                    }
                    
                } else {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Camera Unavailable", nil) message:NSLocalizedString(@"Unable to find a camera on your device.", nil) preferredStyle:UIAlertControllerStyleActionSheet];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
                    [_parentViewController presentViewController:alert animated:YES completion:nil];
                }
                break;
            }
            case 3: {
                
                UIAlertController *shareLocationController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Share My Location", nil)
                                                                                                 message:nil
                                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                
                UIAlertAction *oneHourShareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Share for One Hour", nil)
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareOneHour]; }];
                [shareLocationController addAction:oneHourShareAction];
                
                UIAlertAction *oneDayShareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Share for One Day", nil)
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareOneDay]; }];
                [shareLocationController addAction:oneDayShareAction];
                
                UIAlertAction *indefintelyShareAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Share Indefinitely", nil)
                                                                                 style:UIAlertActionStyleDefault
                                                                               handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeShareIndefinitely]; }];
                [shareLocationController addAction:indefintelyShareAction];
                
                if([ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime > 0) {
                    
                    UIAlertAction *stopSharingAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Stop sharing my location", nil)
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction *action) { [self updateLocationSharingWithTime:kSCLocationTimeStopSharing]; }];
                    [shareLocationController addAction:stopSharingAction];
                }
                
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", ni)
                                                                       style:UIAlertActionStyleCancel
                                                                     handler:nil];
                
                [shareLocationController addAction:cancelAction];
                
                UIPopoverPresentationController *sharePopover = [shareLocationController popoverPresentationController];
                [shareLocationController setModalPresentationStyle:UIModalPresentationPopover];
                sharePopover.sourceView = button;
                CGRect locationFrame = button.frame;
                locationFrame.origin.y += button.frame.size.height / 2;
                sharePopover.sourceRect = locationFrame;
                [_parentViewController presentViewController:shareLocationController animated:YES completion:nil];
            }
                break;
            case 4:
                if ([SystemPermissionManager hasPermission:SystemPermission_Contacts])
                    [self showContacts];
                else
                    [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Contacts"];
                break;
            case 5:
                if ([SystemPermissionManager hasPermission:SystemPermission_Microphone]) {
                    // disable accessibility buttons when recording audio
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (UIButton *button in _actionsheetButtonsArray) {
                            [button setAccessibilityElementsHidden:YES];
                        }
                        [self.delegate resignFirstResponderForAction];
                        VoiceRecorderView *recordView = [[VoiceRecorderView alloc] init];
                        recordView.delegate = self;
                        recordView.needsThumbNail = YES;
                        [recordView unfurlOnView:_parentViewController.view
                                         atPoint:CGPointMake(0, 0)];
                    });
                } else {
                    [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Microphone"];
                }
                break;
            default:
                break;
        }
}

- (void)showPhotoLibrary {
     [[NSNotificationCenter defaultCenter] postNotificationName:kActionSheetWillDismissItsSuperView object:self];
//    if (_popOver) {
//        [_popOver dismissPopoverAnimated:NO];
//    }
    _imagePickerController = [UIImagePickerController new];
    
    [_imagePickerController setDelegate:self];
    [_imagePickerController setAllowsEditing:NO];
    
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
        [_imagePickerController setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    else
        [_imagePickerController setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    
    [_imagePickerController setMediaTypes:[UIImagePickerController availableMediaTypesForSourceType:_imagePickerController.sourceType]];
    
    [_parentViewController presentViewController:_imagePickerController animated:YES completion:nil];
}

-(void) openCamera:(NSString*)mediaType
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kActionSheetWillDismissItsSuperView object:self];
    dispatch_async(dispatch_get_main_queue(), ^{
        _imagePickerController = [[UIImagePickerController alloc]init];
        _imagePickerController.delegate = self;
        _imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        _imagePickerController.mediaTypes = @[mediaType];
        _imagePickerController.allowsEditing = NO;
        [_parentViewController presentViewController:_imagePickerController animated:YES completion:nil];
    });
}

- (void)showContacts {
    
    if(![_parentViewController isKindOfClass:[ChatViewController class]])
        return;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kActionSheetWillDismissItsSuperView object:self];

    ChatViewController *chatVC = (ChatViewController *)_parentViewController;
    
    [chatVC presentContactSelection];
}


#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    if ([self.delegate respondsToSelector:@selector(sendMessageWithAssetInfo:)]) {
        [self.delegate sendMessageWithAssetInfo:info];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [[NSNotificationCenter defaultCenter] postNotificationName:kActionSheetWillDismissItsSuperView object:self];
    [picker dismissViewControllerAnimated:NO
                               completion:^{

                                CGFloat runtimeHeight = CGRectGetHeight([_parentViewController navigationController].navigationBar.frame) + CGRectGetHeight(_parentViewController.view.frame) + CGRectGetHeight([UIApplication sharedApplication].statusBarFrame);
                                CGFloat deviceHeight = CGRectGetHeight([UIScreen mainScreen].bounds);

                                // If there's a constraint error, force a contraint reset by
                                // temporarily presenting a VC
                                if(runtimeHeight != deviceHeight) {

                                    UIViewController *emptyController = [UIViewController new];
                                    [emptyController.view setBackgroundColor:[UIColor clearColor]];

                                    [_parentViewController presentViewController:emptyController
                                                                        animated:NO
                                                                      completion:^{
                                                                          [emptyController dismissViewControllerAnimated:NO
                                                                                                              completion:nil];
                                                                      }];
                                }
                               }];
}

#pragma mark - VoiceRecorderViewDelegate

- (void)voiceRecorderView:(VoiceRecorderView *)voiceRecorderView didFinishRecordingAttachment:(SCAttachment *)attachment error:(NSError *)error {
    
    // enable accessibility buttons when recording audio
    for (UIButton *button in _actionsheetButtonsArray) {
        [button setAccessibilityElementsHidden:NO];
        //[button setAccessibilityLabel:button.titleLabel.text];
    }
    if (error) {
        // TODO: present UIAlertView
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(sendMessageWithAttachment:)])
        [self.delegate sendMessageWithAttachment:attachment];
}
-(void)didCancelVoiceRecording
{
    // enable accessibility buttons when recording audio
    for (UIButton *button in _actionsheetButtonsArray) {
        [button setAccessibilityElementsHidden:NO];
        //[button setAccessibilityLabel:button.titleLabel.text];
    }
}

-(void) updateLocationButtonAfterTimer {
    
    if([ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL)) {
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateButtonImages) object:nil];
        [self performSelector:@selector(updateButtonImages) withObject:nil afterDelay:[ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime - time(NULL)];
    }
}

-(void) updateButtonImages
{
    if([ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
    {
        _locationButtontitleImageView.image = [UIImage actionSheetShareLocationOn];
        [self startAnimatingLocation];
    }
    else {
        
        [[LocationManager sharedManager] stopUpdatingLocation];
         _locationButtontitleImageView.image = [UIImage actionSheetShareLocationOff];
        [self stopAnimatingLocation];
    }
}

- (void)updateLocationSharingWithTime:(SCLocationTimeType)locationTimeType {
    
    
    if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        lastSelectedLocationTimeType = locationTimeType;
        shouldTurnOnLocationAutomaticallyAfterAquiringLocation = YES;
        if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
        {
            [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Location"];
            return;
        }
        
        [[LocationManager sharedManager] requestLocationPermission];
        return;
    }
    long newLocationTime = 0;
    switch (locationTimeType) {
            
        case kSCLocationTimeShareOneHour: {
            [[LocationManager sharedManager] startUpdatingLocation];
            newLocationTime = time(NULL) + 60 * 60; // share for one hour
            [self updateLocationButtonAfterTimer];
        }
            break;
            
        case kSCLocationTimeShareOneDay: {
            [[LocationManager sharedManager] startUpdatingLocation];
            newLocationTime = time(NULL) + 60 * 60 * 24; // share for one day
            [self updateLocationButtonAfterTimer];
        }
            break;
            
        case kSCLocationTimeShareIndefinitely: {
            [[LocationManager sharedManager] startUpdatingLocation];
            newLocationTime = time(NULL) + 60 * 60 * 24 * 365; // share indefinitely
        }
            break;
            
        case kSCLocationTimeStopSharing: {
            [[LocationManager sharedManager] stopUpdatingLocation];
            newLocationTime = 0; // stop sharing
        }
            break;
    }
    if (newLocationTime != [ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime)
    {
        [ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime = newLocationTime;
        [[DBManager dBManagerInstance] saveRecentObject:[ChatUtilities utilitiesInstance].selectedRecentObject];
    }
    
    [self updateButtonImages];
}

-(void) startAnimatingLocation
{
    _locationButtonWidth.constant = 45;
    _locationButtonHeight.constant = 45;
    [UIView animateWithDuration:0.2f
                          delay:0.0f
                        options:UIViewAnimationCurveEaseOut |
     UIViewAnimationOptionRepeat |
     UIViewAnimationOptionAutoreverse
                     animations:^{
                         [self layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {

                     }];
}

-(void)stopAnimatingLocation
{
    _locationButtonWidth.constant = 40;
    _locationButtonHeight.constant = 40;
    //[self.layer removeAllAnimations];
    [_locationButtontitleImageView.layer removeAllAnimations];
}

-(void) didChangeLocationAuthorizationStatus
{
    [CLLocationManager authorizationStatus];
    
    // only called when user enables location for the first time
    if (shouldTurnOnLocationAutomaticallyAfterAquiringLocation)
    {
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse)
        {
            [self updateLocationSharingWithTime:lastSelectedLocationTimeType];
            shouldTurnOnLocationAutomaticallyAfterAquiringLocation = NO;
            return;
        }
    }
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        [[LocationManager sharedManager] stopUpdatingLocation];
        [ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime = 0; // stop sharing
    }
    [self updateButtonImages];
}
#pragma mark - ABPeoplePickerNavigationController Delegate


- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
//    if (_popOver) {
//        [_popOver dismissPopoverAnimated:NO];
//    }
    
    [peoplePicker dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
    
    return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
    
    return YES;
}





- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if([keyPath isEqualToString:@"frame"]) {
        
        CGRect changedFrame = CGRectZero;
        
        if([object valueForKeyPath:keyPath] != [NSNull null]) {
            changedFrame = [[object valueForKeyPath:keyPath] CGRectValue];
        }
        
        CGRect frame;
        frame = self.frame;
        frame.origin.y = changedFrame.origin.y + changedFrame.size.height;
        self.frame = frame;
    }
}




@end
