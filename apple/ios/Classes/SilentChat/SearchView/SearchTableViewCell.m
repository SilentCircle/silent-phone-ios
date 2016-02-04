/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#define kContactImageLeftOffset 1

#import "SearchTableViewCell.h"
#import "Utilities.h"

@implementation SearchTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _contactFullNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.height*1.5f, 0, [Utilities utilitiesInstance].screenWidth - self.frame.size.height , 20)];
        _contactFullNameLabel.font = [UIFont systemFontOfSize:16];
        [_contactFullNameLabel setTextAlignment:NSTextAlignmentLeft];
        [_contactFullNameLabel setTextColor:[UIColor whiteColor]];
        
        _contactPhoneLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.height*2, 20, [Utilities utilitiesInstance].screenWidth - self.frame.size.height , 20)];
        _contactPhoneLabel.font = [UIFont systemFontOfSize:14];
         [_contactPhoneLabel setTextColor:[UIColor lightGrayColor]];
        [_contactPhoneLabel setTextAlignment:NSTextAlignmentLeft];
        
         _contactImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kContactImageLeftOffset, kContactImageLeftOffset, self.frame.size.height - kContactImageLeftOffset *2, self.frame.size.height - kContactImageLeftOffset*2)];
        _contactImageView.layer.cornerRadius = _contactImageView.frame.size.height/2;
        //_contactImageView.layer.borderWidth = 0.2f;
        //[_contactImageView.layer setBorderColor:[UIColor redColor].CGColor];
        _contactImageView.layer.masksToBounds = YES;
        
        _contactInitials = [[ChatBubbleLabel alloc] initWithFrame:_contactImageView.frame];
        _contactInitials.edgeInsets = UIEdgeInsetsMake(0, 3, 0, 3);
        
        [_contactInitials setFont:[[Utilities utilitiesInstance] getFontWithSize:20]];
        [_contactInitials setTextAlignment:NSTextAlignmentCenter];
        _contactInitials.numberOfLines = 1;
        _contactInitials.adjustsFontSizeToFitWidth = YES;
        
        [self.contentView addSubview:_contactImageView];
        [self.contentView addSubview:_contactFullNameLabel];
        [self.contentView addSubview:_contactPhoneLabel];
        [self.contentView addSubview:_contactInitials];
    }
    return self;
}
@end
