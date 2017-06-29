//
//  GroupActionTableViewCell.m
//  SPi3
//
//  Created by Gints Osis on 05/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupActionTableViewCell.h"

@implementation GroupActionTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+(NSString *)reuseIdentifier
{
    return @"SCSLeaveGroupCell_ID";
}

- (IBAction)leaveGroupAction:(id)sender
{
    if([self.delegate respondsToSelector:@selector(leaveGroupTapped)])
    {
        [self.delegate leaveGroupTapped];
    }
}

@end
