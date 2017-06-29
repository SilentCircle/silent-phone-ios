//
//  SCSSearchBarView.m
//  SPi3
//
//  Created by Gints Osis on 27/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSSearchBarView.h"

@implementation SCSSearchBarView

- (IBAction)clearButtonTap:(id)sender
{
    _searchTextField.text = @"";
    [self updateClearButtonForText:_searchTextField.text];
    if ([_delegate respondsToSelector:@selector(didTapClearSearchButton)])
    {
        [_delegate didTapClearSearchButton];
    }
}

-(void) updateClearButtonForText:(NSString *) text
{
    if (text.length == 0)
    {
        [UIView animateWithDuration:0.2f animations:^{
            _clearImageView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [_clearButton setHidden:YES];
        }];
    } else
    {
        [UIView animateWithDuration:0.2f animations:^{
            _clearImageView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [_clearButton setHidden:NO];
        }];
    }
}

- (void) clearSearch
{
    [self clearButtonTap:_clearButton];
}

#pragma mark TextFieldDelegate
-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *textFieldString = [textField.text stringByReplacingCharactersInRange:range
                                                                        withString:string];
    
    if ([_delegate respondsToSelector:@selector(searchTextDidChange:)])
    {
        [_delegate searchTextDidChange:textFieldString];
    }
    
    [self updateClearButtonForText:textFieldString];
    return YES;
}
@end
