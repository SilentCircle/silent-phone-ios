//
//  GroupInfoTableViewCell.m
//  SPi3
//
//  Created by Gints Osis on 20/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupInfoTableViewCell.h"

@implementation GroupInfoTableViewCell

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
    return @"SCSGroupInfoTableViewCell_ID";
}

@end
