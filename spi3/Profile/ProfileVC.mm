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
//  ProfileVC.m
//  SPi3
//
//  Created by Eric Turner on 10/29/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "ProfileVC.h"
#import "ChatUtilities.h"
#import "ProfileInfoCell.h"
#import "ProfileInfoHeaderCell.h"
//#import "SCSRootViewController.h"
#import "SCPSettingsManager.h"
#import "SCPNotificationKeys.h"
#import "SettingsController.h"
#import "UserService.h"
#import "DevicesViewController.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "UserService.h"
#import "SCSFeatures.h"
#import "SCDRWarningView.h"
#import "SCCImageUtilities.h"
//Categories
#import "UIButton+SCButtons.h"
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"
#import "Silent_Phone-Swift.h"

static NSString * const profileCell = @"ProfileInfoCell";

typedef NS_ENUM(NSUInteger, SCSProfileItemRow) {
    SCSProfileItemRowName,
    SCSProfileItemRowUsername,
    SCSProfileItemRowPhoneNumber,
    SCSProfileItemRowOrganization,
    SCSProfileItemRowSubscriptionPlan,
    SCSProfileItemRowModel,
    SCSProfileItemRowDevices
};

@interface ProfileVC () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    BOOL _isOnline;
    NSArray *_rows;
    BOOL _hasProfilePhoto;
    float _scrollViewLastOffset;
}

@property (weak, nonatomic) IBOutlet UIView *topBackgroundView;
@property (weak, nonatomic) IBOutlet UIImageView *profileImageView;
@property (weak, nonatomic) IBOutlet SCSContactView *ivProfile;
@property (weak, nonatomic) IBOutlet UIProgressView *pvAccountStatus;
@property (weak, nonatomic) IBOutlet UILabel *lbAccountStatus;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *loadingContainerView;
@property (weak, nonatomic) IBOutlet UIButton *changeProfileButton;
@property (strong, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIButton *changeAccountButton;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundProfileImageView;
@property (weak, nonatomic) IBOutlet UIVisualEffectView *backgroundEffectView;
@property (weak, nonatomic) IBOutlet UILabel *headerFullNameLabel;
@property (weak, nonatomic) IBOutlet UIView *headerAccountStatusView;
@property (weak, nonatomic) IBOutlet UILabel *headerAccountStatusLabel;

@property (weak, nonatomic) IBOutlet UIButton *dataRetentionButton;

@property (strong, nonatomic) NSArray *accountIndexes;
@property (strong, nonatomic) UITapGestureRecognizer *tapGR;

@end

@implementation ProfileVC


#pragma mark - Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidUpdate:)
                                                 name:kSCSUserServiceUserDidUpdateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleEngineDidUpdateNotification:)
                                                 name:kSCPEngineStateDidChangeNotification
                                               object:nil];
    
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 1)];
    
    NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:[UserService currentUser].displayName];
    
    [_ivProfile setIsAccessibilityElement:YES];
    [_ivProfile setAccessibilityLabel:NSLocalizedString(@"Profile Picture", nil)];
    [_ivProfile setInitials:initials];
    [_ivProfile showDefaultContactColorWithContactName:[UserService currentUser].userID];
    
    [self loadProfileImage];
    
    _tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedProfileImage)];
    [_tapGR setNumberOfTapsRequired:1];
    [_tapGR setNumberOfTouchesRequired:1];
    [_ivProfile addGestureRecognizer:_tapGR];
    
    [self buildRows];
    
    [self updateUserFullName];
    [self updateUserStatus];
#if HAS_DATA_RETENTION
    _dataRetentionButton.hidden = (![UserService currentUser].drEnabled);
#else
    _dataRetentionButton.hidden = YES;
#endif // HAS_DATA_RETENTION

}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    _accountIndexes = [Switchboard indexesOfUniqueAccounts];
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDelegate

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if([_accountIndexes count] == 1)
        return nil;

    ProfileInfoHeaderCell *headerView = [tableView dequeueReusableCellWithIdentifier:@"header"];
    
    if(section == 0)
        [headerView.label setText:NSLocalizedString(@"Accounts", nil)];
    else
        [headerView.label setText:NSLocalizedString(@"Details", nil)];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    
    if([_accountIndexes count] == 1)
        return 0;
    
    return 44.0f;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    if([_rows count] == 0)
        return 1;
    
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if(section == 0)
        return [_accountIndexes count];
    else
        return [_rows count];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header setBackgroundView:[UIView new]];
    [header.textLabel setTextColor:[UIColor whiteColor]];
    [header.backgroundView setBackgroundColor:[UIColor profileHeaderBgColor]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileInfoCell *cell = (ProfileInfoCell *)[tableView dequeueReusableCellWithIdentifier:profileCell forIndexPath:indexPath];
    
    // Reset cell
    [cell.accountStatus setHidden:YES];
    [cell.accountStatusText setHidden:YES];
    [cell.addLabel setHidden:YES];
    [cell.text setHidden:NO];
    [cell.textTrailingMargin setConstant:5];
    [cell.header setFont:[UIFont fontWithName:@"Arial" size:16.0f]];
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    
    if(indexPath.section == 0) {
        
        NSInteger idx = ((NSNumber*)[_accountIndexes objectAtIndex:indexPath.row]).integerValue;
        
        void *eng = [Switchboard accountAtIndex:idx];
        
        NSString *un = [Switchboard usernameForAccount:eng];
        
        if([[ChatUtilities utilitiesInstance] isUUID:un])
            un = [[UserService currentUser] displayAlias];
        
        BOOL isSelected = [Switchboard accountAtIndexIsCurrentDOut:idx];
        
        if([_accountIndexes count] == 1) {
            
            [cell.header setText:NSLocalizedString(@"Username", nil)];
            [cell.text setText:un];
            
        } else {
            
            [cell.header setText:un];
            [cell.text setHidden:YES];
            [cell.accountStatus setHidden:NO];
            [cell.accountStatusText setHidden:NO];

            if(isSelected)
                [cell.header setFont:[UIFont fontWithName:@"Arial-BoldMT" size:17.0f]];
            
            NSString *currentState = [Switchboard currentDOutState:eng];
            
            if([currentState isEqualToString:@"yes"]) {
                
                [cell.accountStatus setBackgroundColor:[UIColor connectivityOnlineColor]];
                [cell.accountStatusText setText:NSLocalizedString(@"Online", nil)];
                
            } else if([currentState isEqualToString:@"connecting"]) {
                
                [cell.accountStatus setBackgroundColor:[UIColor connectivityConnectingColor]];
                [cell.accountStatusText setText:NSLocalizedString(@"Connecting", nil)];
                
            } else {
                
                NSString * str = [Switchboard regErrorForAccount:eng];
                [cell.accountStatus setBackgroundColor:[UIColor connectivityOfflineColor]];
                
                if(str && str.length)
                    [cell.accountStatusText setText:str];
                else
                    [cell.accountStatusText setText:NSLocalizedString(@"Offline", nil)];
            }
        }
        
        [cell.icon setImage:[UIImage imageNamed:@"UserNameIcon"]];
    }
    else
    {
        SCSProfileItemRow itemRow = (SCSProfileItemRow)[[_rows objectAtIndex:indexPath.row] intValue];

        if(itemRow == SCSProfileItemRowSubscriptionPlan)
        {
            NSString *text = [UserService currentUser].displayPlan;            
            [cell.header setText:NSLocalizedString(@"Subscription plan", nil)];
            [cell.text setText:text];
            // adjust cell height to accomodate multiple rows
            //[cell.text setNumberOfLines:0];
            [cell.text sizeToFit];
            
            [cell.icon setImage:[UIImage imageNamed:@"SubscriptionPlanIcon"]];
        }
        else if(itemRow == SCSProfileItemRowModel)
        {
            if([[UserService currentUser].model isEqualToString:@"plan"])
            {
                [cell.header setText:NSLocalizedString(@"Remaining minutes", nil)];
                [cell.text setText:[NSString stringWithFormat:@"%d / %d", [UserService currentUser].minutesLeft, [UserService currentUser].totalMinutes]];
                
                [cell.icon setImage:[UIImage imageNamed:@"RemainingMinutesIcon"]];
            }
            else
            {
                [cell.header setText:NSLocalizedString(@"Remaining credit", nil)];
                [cell.text setText:[NSString stringWithFormat:@"%.2f %@",[UserService currentUser].remainingCredit, [UserService currentUser].creditCurrency]];

                [cell.icon setImage:[UIImage imageNamed:@"RemainingCreditIcon"]];
            }
        }
        else if(itemRow == SCSProfileItemRowDevices)
        {
            [cell.header setText:NSLocalizedString(@"Devices", nil)];
            [cell.text setText:[NSString stringWithFormat:@"%d %@", [UserService currentUser].devicesCnt, NSLocalizedString(@"provisioned", nil)]];
            [cell.textTrailingMargin setConstant:0];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];

            [cell.icon setImage:[UIImage imageNamed:@"DeviceIcon"]];
        }
        else if(itemRow == SCSProfileItemRowOrganization)
        {
            [cell.header setText:NSLocalizedString(@"Organization", nil)];
            [cell.text setText:[UserService currentUser].displayOrganization];

            [cell.icon setImage:[UIImage imageNamed:@"OrganizationIcon"]];
        }
        else if(itemRow == SCSProfileItemRowPhoneNumber)
        {
            [cell.header setText:NSLocalizedString(@"Phone Number", nil)];
            [cell.text setText:[UserService currentUser].displayTN];
            
            [cell.icon setImage:[UIImage imageNamed:@"ProfileCallIcon"]];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0)
    {
        if([_accountIndexes count] <= 1)
            return;
        
        NSInteger idx = ((NSNumber*)[_accountIndexes objectAtIndex:indexPath.row]).integerValue;
        
        void *eng = [Switchboard accountAtIndex:idx];
        [Switchboard setCurrentDOut:eng];
        
        [self buildRows];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
    else
    {
        SCSProfileItemRow itemRow = (SCSProfileItemRow)[[_rows objectAtIndex:indexPath.row] intValue];

        if(itemRow == SCSProfileItemRowDevices)
        {
            UIStoryboard *chatStoryBoard = [UIStoryboard storyboardWithName:@"Chat" bundle:nil];
            DevicesViewController *devicesViewController = (DevicesViewController*)[chatStoryBoard instantiateViewControllerWithIdentifier:@"DevicesViewController"];
            [devicesViewController setTransitionDelegate:_transitionDelegate];
            [self.navigationController pushViewController:devicesViewController
                                                 animated:YES];
        }
    }
}
#pragma mark UIScrollViewDelegate
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(scrollView.contentOffset.y <0) {
        
        CGPoint currentOffset = scrollView.contentOffset;
        _tableHeaderViewHeightConstraint.constant -=currentOffset.y - _scrollViewLastOffset;
        _scrollViewLastOffset = currentOffset.y;
    }
}

#pragma mark - Navigation

- (void)goToSettingsVC {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SettingsController *vc = [sb instantiateViewControllerWithIdentifier:@"SettingsController"];
    [vc setTitle:NSLocalizedString(@"Settings", nil)];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Notifications

- (void)handleEngineDidUpdateNotification:(NSNotification *)notification {
    
    _accountIndexes = [Switchboard indexesOfUniqueAccounts];
     
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self updateUserFullName];
        [self updateUserStatus];
        [self.tableView reloadData];
    });
}

- (void)userDidUpdate:(NSNotification*)notification {
    
    [self loadProfileImage];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self buildRows];
        [self updateUserFullName];
        [self.tableView reloadData];
#if HAS_DATA_RETENTION
        _dataRetentionButton.hidden = ![UserService currentUser].drEnabled;
#endif // HAS_DATA_RETENTION
    });
}

#pragma mark - IB actions

- (IBAction)tappedChangeProfileButton:(id)sender {
    
    [self tappedProfileImage];
}

- (IBAction)dataRetentionInfoTapped:(id)sender {
#if HAS_DATA_RETENTION    
    [SCDRWarningView presentInfoInVC:self recipient:nil];
#endif // HAS_DATA_RETENTION
}

#pragma mark - Private

- (void)loadProfileImage {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *profileImage = [[ChatUtilities utilitiesInstance] getProfileImage];
        UIImage *roundProfileImage = [SCCImageUtilities roundAvatarImage:profileImage];
        
        
        dispatch_async(dispatch_get_main_queue(), ^{

            _hasProfilePhoto = (profileImage != nil);

            [_loadingContainerView setHidden:YES];
            [_backgroundProfileImageView setImage:profileImage];
            
            if(_hasProfilePhoto)
                [_ivProfile setImage:roundProfileImage];
            else {
                
                NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:[UserService currentUser].displayName];
                [_ivProfile setInitials:initials];
                _ivProfile.layer.cornerRadius = _ivProfile.frame.size.width / 2;
                _ivProfile.clipsToBounds = YES;
                [_ivProfile showDefaultContactColorWithContactName:[UserService currentUser].userID];
            }
        });
    });
}

- (void)updateUserFullName {
    SPUser *currentUser = [UserService currentUser];
    if (!currentUser)
        return;
    if ( (currentUser.displayName) && ([currentUser.displayName length] > 0) ) {
        [_headerFullNameLabel setText:currentUser.displayName];
        [_headerFullNameLabel setHidden:NO];
    } else if ( (currentUser.displayAlias) && ([currentUser.displayAlias length] > 0) ) {
        [_headerFullNameLabel setText:currentUser.displayAlias];
        [_headerFullNameLabel setHidden:NO];
    }
}

- (void)updateUserStatus {
    
    NSInteger idx = ((NSNumber*)[_accountIndexes objectAtIndex:0]).integerValue;
    
    void *eng = [Switchboard accountAtIndex:idx];
    
    NSString *currentState = [Switchboard currentDOutState:eng];
    
    if([currentState isEqualToString:@"yes"]) {
        
        [_headerAccountStatusView setBackgroundColor:[UIColor connectivityOnlineColor]];
        [_headerAccountStatusLabel setText:NSLocalizedString(@"Online", nil)];
        
    } else if([currentState isEqualToString:@"connecting"]) {
        
        [_headerAccountStatusView setBackgroundColor:[UIColor connectivityConnectingColor]];
        [_headerAccountStatusLabel setText:NSLocalizedString(@"Connecting", nil)];
        
    } else {
        
        NSString * str = [Switchboard regErrorForAccount:eng];
        [_headerAccountStatusView setBackgroundColor:[UIColor connectivityOfflineColor]];
        
        if(str && str.length)
            [_headerAccountStatusLabel setText:NSLocalizedString(str, nil)];
        else
            [_headerAccountStatusLabel setText:NSLocalizedString(@"Offline", nil)];
    }
    
    [_headerAccountStatusLabel setHidden:NO];
    [_headerAccountStatusView setHidden:NO];
}

- (void)buildRows {
    
    NSMutableArray *tempRows = [NSMutableArray new];
    
    if([UserService currentUser].displayTN)
        [tempRows addObject:@(SCSProfileItemRowPhoneNumber)];
    
    if([UserService currentUser].displayOrganization)
        [tempRows addObject:@(SCSProfileItemRowOrganization)];
    
    if([UserService currentUser].displayPlan)
        [tempRows addObject:@(SCSProfileItemRowSubscriptionPlan)];
    
    if([UserService currentUser].model)
        [tempRows addObject:@(SCSProfileItemRowModel)];
    
    if([UserService currentUser].devicesCnt > 0)
        [tempRows addObject:@(SCSProfileItemRowDevices)];
    
    _rows = tempRows;
}

- (void)tappedProfileImage {
    
    UIAlertController *profileChoices = [UIAlertController alertControllerWithTitle:nil
                                                                            message:nil
                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
            
        UIAlertAction *cameraUpload = [UIAlertAction actionWithTitle:NSLocalizedString(@"Take Photo", nil)
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 [self presentImagePicker:UIImagePickerControllerSourceTypeCamera];
                                                             }];
        [profileChoices addAction:cameraUpload];
    }

    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        
        UIAlertAction *photoUpload = [UIAlertAction actionWithTitle:NSLocalizedString(@"Choose Existing Photo", nil)
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 [self presentImagePicker:UIImagePickerControllerSourceTypePhotoLibrary];
                                                             }];
        [profileChoices addAction:photoUpload];
    }
    
    if(_hasProfilePhoto) {
        
        UIAlertAction *removeProfile = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Profile Picture", nil)
                                                                style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction * _Nonnull action) {
                                                                  [self removeProfilePic];
                                                              }];
        [profileChoices addAction:removeProfile];
    }
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [profileChoices addAction:cancelAction];
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
    
        UIPopoverPresentationController *popPresenter = [profileChoices
                                                         popoverPresentationController];
        popPresenter.sourceView = _changeProfileButton;
        popPresenter.sourceRect = _changeProfileButton.bounds;
    }
    
    [self presentViewController:profileChoices animated:YES completion:nil];
}

- (void)presentImagePicker:(UIImagePickerControllerSourceType)sourceType {
    
    UIImagePickerController *ipController = [UIImagePickerController new];
    [ipController setDelegate:self];
    [ipController setAllowsEditing:YES];
    [ipController setSourceType:sourceType];
    
    [self presentViewController:ipController animated:YES completion:nil];
}

#pragma mark - Avatar Handling

- (void)startUploadingProfilePicWithImage:(UIImage*)image {
    
    if(!image)
        return;
    
    NSData *imageData = UIImageJPEGRepresentation(image, .5);
    
    if(!imageData)
        return;
    
    NSDictionary *dictionary = @{ @"image": [imageData base64EncodedStringWithOptions:0] };
    
    [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1MeAvatar
                                              method:SCPNetworkManagerMethodPOST
                                           arguments:dictionary
                                          completion:nil];
}

- (void)removeProfilePic {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_loadingContainerView setHidden:NO];
    });
    
    [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1MeAvatar
                                              method:SCPNetworkManagerMethodDELETE
                                           arguments:nil
                                          completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {

    [picker dismissViewControllerAnimated:YES completion:NULL];

    [_loadingContainerView setHidden:NO];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *chosenImage = info[UIImagePickerControllerOriginalImage];
        
        if(info[UIImagePickerControllerEditedImage])
            chosenImage = info[UIImagePickerControllerEditedImage];
        
        CGSize size = chosenImage.size;
        
        if(size.width <= 512 && size.height <= 512) {
            
            [self startUploadingProfilePicWithImage:chosenImage];
            return;
        }
        
        double smallerEdge = (size.width < size.height ? size.width : size.height);
        double scale = 512. / smallerEdge;
        
        CGSize newSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(scale, scale));
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(512., 512.), YES, 0.0);
        [chosenImage drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
        
        UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [self startUploadingProfilePicWithImage:scaledImage];
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    [picker dismissViewControllerAnimated:YES completion:NULL];
}

@end
