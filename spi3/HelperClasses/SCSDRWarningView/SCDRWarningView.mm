/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  SCDRWarningView.m
//  Silent Phone
//
//  Created by Ethan Arutunian on 9/27/16.
//  Copyright (c) 2016 Silent Circle. All rights reserved.
//

#import "SCDRWarningView.h"
#import "SCSFeatures.h"
#import "UserService.h"

// external methods
void *findGlobalCfgKey(const char *key);

@implementation SCDRWarningView

- (void)awakeFromNib {
    [super awakeFromNib];
#if HAS_DATA_RETENTION
    [_drButton addTarget:self action:@selector(infoTapped:) forControlEvents:UIControlEventTouchUpInside];
#else
    _drButton.hidden = YES;
#endif // HAS_DATA_RETENTION
}

- (void)positionWarningAboveConstraint:(NSLayoutConstraint *)topOfViewBelow offsetY:(CGFloat)offsetY {
    _topOfViewBelow = topOfViewBelow;
    _offsetY = offsetY;
}

- (void)positionWarningAboveConstraint:(NSLayoutConstraint *)topOfViewBelow {
    [self positionWarningAboveConstraint:topOfViewBelow offsetY:0];
    _topOfViewBelow = topOfViewBelow;
}

#if HAS_DATA_RETENTION
- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    CGRect drFrame = self.frame;
    if (_enabled) {
        if (_warningViewTopConstant)
            _warningViewTopConstant.constant = _offsetY;
        self.hidden = NO;
        if (_topOfViewBelow)
            _topOfViewBelow.constant = drFrame.size.height + _offsetY;

        if ([UserService isDRBlockedForContact:_recipient])
            [_drButton setTitle:NSLocalizedString(@"Communication Prohibited", nil) forState:UIControlStateNormal];
        else
            [_drButton setTitle:NSLocalizedString(@"Data Retention ON", nil) forState:UIControlStateNormal];
    } else {
        if (_warningViewTopConstant)
            _warningViewTopConstant.constant = _offsetY - drFrame.size.height;
        self.hidden = YES;
        if (_topOfViewBelow)
            _topOfViewBelow.constant = _offsetY;
    }
}

- (void)enableWithRecipient:(RecentObject *)recipient {
    _recipient = recipient;
    BOOL myChatHasDR = [UserService currentUser].drEnabled;
    BOOL bRecipientHasDR = _recipient.drEnabled;
    self.enabled = ( (myChatHasDR) || (bRecipientHasDR) );
}

- (IBAction)infoTapped:(id)sender {
    if (_infoHolderVC) {
        [SCDRWarningView presentInfoInVC:_infoHolderVC recipient:_recipient];
    }
}

+ (void)presentInfoInVC:(UIViewController *)holderVC recipient:(RecentObject *)recipient {
    // load/show the info view in this view controller
    BOOL myChatHasDR = [UserService currentUser].drEnabled;
    BOOL bRecipientHasDR = recipient.drEnabled;
    if ( (!myChatHasDR) && (!bRecipientHasDR) )
        return;
    
    NSString *retainer = (myChatHasDR) ? @"Your organization" : @"Recipient's organization";
    NSString *verb = @"has";
    NSString *organizationS = @"organization";
    NSString *orgNames = (myChatHasDR) ? [UserService currentUser].drOrganization : recipient.drOrganization;
    if (orgNames == nil)
        orgNames = @"";
    
    if ( (myChatHasDR) && (bRecipientHasDR) ) {
        retainer = @"Your organization and recipient's organization";
        verb = @"have";
        
        if ( ([recipient.drOrganization length] > 0) && (![recipient.drOrganization isEqualToString:orgNames]) ) {
            if ([orgNames length] == 0)
                orgNames = recipient.drOrganization;
            else {
                organizationS = @"organizations";
                orgNames = [[orgNames stringByAppendingString:@", "] stringByAppendingString:recipient.drOrganization];
            }
        }
    }
    if ([orgNames length] == 0)
        orgNames = @"N/A";
    
    NSMutableArray *bullets = [NSMutableArray arrayWithCapacity:5];
    if ( ((myChatHasDR) && ([UserService currentUser].drTypeCode & kDRType_Call_Metadata))
                || ((bRecipientHasDR) && (recipient.drTypeCode & kDRType_Call_Metadata)) )
        [bullets addObject:@"- Call metadata"];
    if ( ((myChatHasDR) && ([UserService currentUser].drTypeCode & kDRType_Message_Metadata))
                || ((bRecipientHasDR) && (recipient.drTypeCode & kDRType_Message_Metadata)) )
        [bullets addObject:@"- Message metadata"];
    if ( ((myChatHasDR) && ([UserService currentUser].drTypeCode & kDRType_Message_PlainText))
                || ((bRecipientHasDR) && (recipient.drTypeCode & kDRType_Message_PlainText)) )
        [bullets addObject:@"- Message contents"];
/* TODO: put these back in when these features are implemented
    if ( ((myChatHasDR) && ([UserService currentUser].drTypeCode & kDRType_Call_PlainText))
        || ((bRecipientHasDR) && (recipient.drTypeCode & kDRType_Call_PlainText)) )
        [bullets addObject:@"- Call audio"];
    if ( ((myChatHasDR) && ([UserService currentUser].drTypeCode & kDRType_Attachment_PlainText))
                || ((bRecipientHasDR) && (recipient.drTypeCode & kDRType_Attachment_PlainText)) )
        [bullets addObject:@"- Attachment contents"];
 */
    NSString *bulletListS = [bullets componentsJoinedByString:@"\n"];
        if ([bulletListS length] == 0)
            bulletListS = @"N/A";
    
    NSString *msg = [NSString stringWithFormat:@"%@ %@ a policy of retaining conversation data.\n"\
                     "Silent Phone is retaining this data and uploading it to %@.\n\n"\
                     "Retaining %@: %@\n\n"\
                     "Data being retained:\n\n%@"
                     , retainer, verb, [retainer lowercaseString], organizationS, orgNames, bulletListS];
    
//        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
//        paragraphStyle.alignment= NSTextAlignmentLeft;
//        NSDictionary *attribs = @{NSParagraphStyleAttributeName:paragraphStyle};
//        NSAttributedString *msgAttributed = [[NSAttributedString alloc] initWithString:msg attributes:attribs];

    UIAlertController *alertC = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Data Retention", nil) message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        // nothing to do
    }];
    [alertC addAction:okAction];
    
    [holderVC presentViewController:alertC animated:YES completion:nil];
}
#endif // HAS_DATA_RETENTION

@end
