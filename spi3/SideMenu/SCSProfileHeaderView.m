//
//  SCSPProfileHeaderView.m
//  SPi3
//
//  Created by Eric Turner on 3/14/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//
#import "Silent_Phone-Swift.h"
#import "SCSProfileHeaderView.h"

#import "ChatUtilities.h"
#import "SCPNotificationKeys.h"
#import "SCPCallbackInterface.h"
#import "UserService.h"
#import "SCCImageUtilities.h"
//Categories
#import "UIColor+ApplicationColors.h"

@interface SCSProfileHeaderView ()
@end

@implementation SCSProfileHeaderView

- (void)prepareToShow {

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidUpdate:)
                                                 name:kSCPEngineStateDidChangeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidUpdate:)
                                                 name:kSCSUserServiceUserDidUpdateNotification
                                               object:nil];
    [self userDidUpdate:nil];
}

- (void)stopShowing {

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPEngineStateDidChangeNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSUserServiceUserDidUpdateNotification 
                                                  object:nil];
}

- (void)userDidUpdate:(NSNotification*)notification {
    
    [self loadProfileImage];
    [self updateDisplayName];
    [self updateDisplayAlias];
    [self updateUserStatus];
}


#pragma mark - Private

- (void)loadProfileImage {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *profileImg = [[ChatUtilities utilitiesInstance] getProfileImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            _loadingView.hidden = YES;
            _bgProfileImageView.image = profileImg;
            
            if(profileImg)
                _profileContactView.image = [SCCImageUtilities roundAvatarImage:profileImg];
            else {                
                NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:[UserService currentUser].displayName];
                _profileContactView.initials = initials;
                _profileContactView.layer.cornerRadius = _profileContactView.frame.size.width / 2;
                _profileContactView.clipsToBounds = YES;
                [_profileContactView showDefaultContactColorWithContactName:[UserService currentUser].userID];
            }
        });
    });
}

- (void)updateDisplayName {
    SPUser *currentUser = [UserService currentUser];
    if (!currentUser)
        return;
    if ( (currentUser.displayName) && ([currentUser.displayName length] > 0) ) {
        _lbDisplayName.text = currentUser.displayName;
        _lbDisplayName.hidden = NO;
    } else if ( (currentUser.displayAlias) && ([currentUser.displayAlias length] > 0) ) {
        _lbDisplayName.text = currentUser.displayAlias;
        _lbDisplayName.hidden = NO;
    }
}

- (void)updateDisplayAlias {
    SPUser *currentUser = [UserService currentUser];
    if (!currentUser)
        return;
    if ( (currentUser.displayAlias) && ([currentUser.displayAlias length] > 0) ) {
        _lbDisplayAlias.text = currentUser.displayAlias;
        _lbDisplayAlias.hidden = NO;
    }
}

- (void)updateUserStatus {
    NSString *state = [Switchboard currentDOutState:NULL];

    if([state isEqualToString:@"yes"]) {
        _onlineStatusView.backgroundColor = [UIColor connectivityOnlineColor];
        _lbOnlineStatus.text = NSLocalizedString(@"Online", nil);
    } 
    else if([state isEqualToString:@"connecting"]) {
        _onlineStatusView.backgroundColor = [UIColor connectivityConnectingColor];
        _lbOnlineStatus.text = NSLocalizedString(@"Connecting", nil);
    } 
    else {
        void *eng = [Switchboard accountAtIndex:0];
        NSString *str = [Switchboard regErrorForAccount:eng];
        _onlineStatusView.backgroundColor = [UIColor connectivityOfflineColor];
        
        if(str && str.length)
            _lbOnlineStatus.text = NSLocalizedString(str, nil);
        else
            _lbOnlineStatus.text = NSLocalizedString(@"Offline", nil);
    }
    
    _onlineStatusView.hidden = NO;
    _lbOnlineStatus.hidden = NO;
}

@end
