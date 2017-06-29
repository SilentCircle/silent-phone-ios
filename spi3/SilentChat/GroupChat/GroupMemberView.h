//
//  GroupMemberView.h
//  SPi3
//
//  Created by Gints Osis on 03/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecentObject.h"
@interface GroupMemberView : UIView
@property (nonatomic, strong) RecentObject *recentObject;

@property (nonatomic, strong) UIImageView *removeImageView;
@property (nonatomic, strong) UITextView *contactNameTextView;
@end
