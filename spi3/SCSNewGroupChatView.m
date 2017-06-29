//
//  SCSNewGroupChatView.m
//  SPi3
//
//  Created by Gints Osis on 27/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSNewGroupChatView.h"
#import "UIColor+ApplicationColors.h"
@implementation SCSNewGroupChatView

- (IBAction)groupChatButtonTouchDown:(id)sender
{
    [UIView animateWithDuration:0.1f animations:^{
        [_backgroundView setBackgroundColor:[UIColor selectedCellBackgroundColor]];
    }];
}

- (IBAction)groupChatButtonTouchUpOutside:(id)sender
{
    [UIView animateWithDuration:0.1f animations:^{
        [_backgroundView setBackgroundColor:[UIColor whiteColor]];
    }];
}

- (IBAction)groupChatButtonTouchUpInside:(id)sender
{
    [UIView animateWithDuration:0.1f animations:^{
        [_backgroundView setBackgroundColor:[UIColor whiteColor]];
    } completion:^(BOOL finished) {
        if ([_delegate respondsToSelector:@selector(didTapNewGroupChatButton)])
        {
            [_delegate didTapNewGroupChatButton];
        }
    }];
}
@end
