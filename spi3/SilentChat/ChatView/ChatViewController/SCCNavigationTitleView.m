//
//  SCCNavigationTitleView.m
//  SPi3
//
//  Created by Gints Osis on 03/05/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCCNavigationTitleView.h"

@implementation SCCNavigationTitleView

- (void)awakeFromNib {
    
    [super awakeFromNib];
    
    [self.tapHereForMoreLabel setText:NSLocalizedString(@"Tap here for more", nil)];
}

@end
