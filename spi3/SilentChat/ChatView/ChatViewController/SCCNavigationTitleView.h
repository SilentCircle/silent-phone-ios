//
//  SCCNavigationTitleView.h
//  SPi3
//
//  Created by Gints Osis on 03/05/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCCNavigationTitleView : UIView

@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *verifiedLabel;
@property (weak, nonatomic) IBOutlet UILabel *tapHereForMoreLabel;
@property (weak, nonatomic) IBOutlet UIStackView *bottomStackView;

@end
