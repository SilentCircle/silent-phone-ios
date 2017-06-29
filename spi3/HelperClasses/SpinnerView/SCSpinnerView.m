//
//  SCSpinnerView.m
//  SPi3
//
//  Created by Eric Turner on 4/24/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSpinnerView.h"

@implementation SCSpinnerView

-(void)awakeFromNib {
    [super awakeFromNib];

    _lbMessage.text = @""; // remove IB text
}

@end
