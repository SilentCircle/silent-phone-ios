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
#define kLineColor [UIColor colorWithRed:84/255.0f green:86/255.0f blue:92/255.0f alpha:1.0f]


#define yOffset 0

#define kTitleInset 5

#define kMinTitleWidth 40
#import "NavigationBarTitleView.h"
#import "Utilities.h"
#import "ChatBubbleLabel.h"

@implementation NavigationBarTitleView

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        //[self setBackgroundColor:[UIColor redColor]];
        UIView *headerLineView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, frame.size.width, 1)];
        [headerLineView setBackgroundColor:kLineColor];
        [self addSubview:headerLineView];
        
    }
    return self;
}

-(void)setTitle:(NSString *)title
{
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    [titleLabel setTextAlignment:NSTextAlignmentCenter];
    [titleLabel setFont:[UIFont fontWithName:@"KarbonMedium" size:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline].pointSize]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel sizeToFit];
    
    CGRect titleLabelFrame = titleLabel.frame;
    
    if(titleLabelFrame.size.width < kMinTitleWidth)
    {
        titleLabelFrame.size.width = kMinTitleWidth;
    }
    [titleLabel setFrame:CGRectMake([Utilities utilitiesInstance].screenWidth /2 - titleLabelFrame.size.width/2, 0, titleLabelFrame.size.width, titleLabelFrame.size.height)];
    [self addSubview:titleLabel];
    
    
    UIView *titleBackgroundView = [[UIView alloc] initWithFrame:CGRectMake([Utilities utilitiesInstance].screenWidth /2 - titleLabelFrame.size.width/2 - kTitleInset, yOffset, titleLabelFrame.size.width + kTitleInset * 2, titleLabelFrame.size.height + kTitleInset)];
    [titleBackgroundView setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
    [self insertSubview:titleBackgroundView belowSubview:titleLabel];
    
    
    UIView *borderView = [[UIView alloc] initWithFrame:CGRectMake([Utilities utilitiesInstance].screenWidth /2 - titleLabelFrame.size.width/2 - 1 - kTitleInset, 1 + yOffset, titleLabelFrame.size.width + 2 + kTitleInset * 2, titleLabel.frame.size.height + kTitleInset)];
    [borderView setBackgroundColor:kLineColor];
    [self addSubview:borderView];
    [self sendSubviewToBack:borderView];
}


@end
