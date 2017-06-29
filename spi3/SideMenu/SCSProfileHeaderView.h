//
//  SCSPProfileHeaderView.h
//  SPi3
//
//  Created by Eric Turner on 3/14/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SCSContactView;

@interface SCSProfileHeaderView : UIView
@property (weak, nonatomic) IBOutlet UIImageView    *bgProfileImageView;
@property (weak, nonatomic) IBOutlet SCSContactView *profileContactView;
@property (weak, nonatomic) IBOutlet UIView         *loadingView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UILabel        *lbDisplayName;
@property (weak, nonatomic) IBOutlet UILabel        *lbDisplayAlias;
@property (weak, nonatomic) IBOutlet UILabel        *lbOnlineStatus;
@property (weak, nonatomic) IBOutlet UIView         *onlineStatusView;

@property (assign, readonly, nonatomic) BOOL accountIsOnline;
@property (weak, readonly, nonatomic) NSString *currentEngState;

- (void)prepareToShow;
- (void)stopShowing;
- (void)updateUserStatus;

@end
