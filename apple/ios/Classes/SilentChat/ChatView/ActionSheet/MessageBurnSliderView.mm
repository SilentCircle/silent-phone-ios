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
#define kSliderOffsetsFromSides 40
#define kViewOffsetFromSides 10

#import "MessageBurnSliderView.h"
#import "Utilities.h"

@implementation MessageBurnSliderView
{
    BOOL isBurningEnabled;
    NSMutableArray *burnTimeNamesArr;
    
    UILabel *burningTimeLabel;
    
    UISlider *slider;
    UIImage *burnOffImage;
    UIImage *burnOnImage;
    
    float savedSliderValue;
    
}
-(id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        // set value as time to burn in minutes, key as text to show
        burnTimeNamesArr = [[NSMutableArray alloc] initWithObjects:
                            // @"0",@"Off",
                             @"1",@"1 Minute",
                             @"5",@"5 Minutes",
                             @"10",@"10 Minutes",
                             @"15",@"15 Minutes",
                             @"30",@"30 Minutes",
                             @"60",@"1 Hour",
                             @"180",@"3 Hours",
                             @"360",@"6 Hours",
                             @"720",@"12 Hours",
                             @"1440",@"1 Day",
                             @"2880",@"2 Days",
                             @"4320",@"3 Days",
                             @"7200",@"5 Days",
                             @"10080",@"1 Week",
                             @"20160",@"2 Weeks",
                             @"40320",@"4 Weeks",
                             @"64800",@"45 Days",
                             @"129600",@"90 Days",
                        //     @"259200",@"180 Days",
                      //       @"525600",@"1 Year",
                             nil];
        isBurningEnabled = YES;
        UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(kViewOffsetFromSides, 0, [Utilities utilitiesInstance].screenWidth - kViewOffsetFromSides*2, self.frame.size.height)];
        //[backgroundView setAlpha:0.4f];
        [backgroundView setBackgroundColor:[UIColor blackColor]];
        [self addSubview:backgroundView];
        
        backgroundView.layer.cornerRadius = 10;
        backgroundView.layer.masksToBounds = YES;
        
        slider = [[UISlider alloc] initWithFrame:CGRectMake(kSliderOffsetsFromSides, 0, self.frame.size.width - kSliderOffsetsFromSides*3, self.frame.size.height)];
        slider.maximumValue = 17.0f;
        slider.continuous = YES;
        
        burnOffImage = [UIImage imageNamed:@"BurnOffForSlider.png"];
        burnOnImage = [UIImage imageNamed:@"BurnOnForSlider.png"];
        
        UIImage *sliderThumbImage = burnOnImage;
        sliderThumbImage = [sliderThumbImage resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
        [slider setThumbImage:sliderThumbImage forState:UIControlStateNormal];
        [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self addSubview:slider];
        
        /*
        UIButton *onOffButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [onOffButton setBackgroundColor:[UIColor redColor]];
        [onOffButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [onOffButton setFrame:CGRectMake(0, 0, self.frame.size.height, self.frame.size.height)];
        [onOffButton setTitle:@"On" forState:UIControlStateNormal];
        [onOffButton.titleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize: onOffButton.titleLabel.font.pointSize]];
        [onOffButton addTarget:self action:@selector(OnOffClick:) forControlEvents:UIControlEventTouchUpInside];
        [onOffButton setTag:1];
        [self addSubview:onOffButton];*/
        
        burningTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.frame.size.width - kSliderOffsetsFromSides*2,0, kSliderOffsetsFromSides*2 - kViewOffsetFromSides, self.frame.size.height)];
        burningTimeLabel.text = burnTimeNamesArr[[Utilities utilitiesInstance].savedBurnStateIndex];
        burningTimeLabel.numberOfLines = 1;
        burningTimeLabel.minimumScaleFactor = 0.1f;
        burningTimeLabel.adjustsFontSizeToFitWidth = YES;
        [burningTimeLabel setTextAlignment:NSTextAlignmentCenter];
        [burningTimeLabel setTextColor:[UIColor whiteColor]];
        [burningTimeLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:14]];
        [self addSubview:burningTimeLabel];
        
        NSString *burnDelayString;
       
        burnDelayString =[NSString stringWithFormat:@"%li",[Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration/60];
        
        for (int i = 0; i < burnTimeNamesArr.count; i++) {
            NSString *thisValue = burnTimeNamesArr[i];
            if([thisValue isEqualToString:burnDelayString])
            {
                slider.value = i/2;
                burningTimeLabel.text = burnTimeNamesArr[i+1];
            }
        }
        
        UIPanGestureRecognizer *releaseGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRelease:)];
        [self addGestureRecognizer:releaseGestureRecognizer];
    }
    return self;
}



- (void) handleRelease : (UIPanGestureRecognizer*)recogniser
{
    if ([self.delegate respondsToSelector:@selector(touchHappened)])
    {
        [self.delegate touchHappened];
    }
}

/**
 * handles touch in burnslider
 * when user touches burnslider, signal delegate(ChatViewController) to stop actionsheetview closing
 **/
- (void)sliderValueChanged:(UISlider *)sender {
    savedSliderValue = sender.value;
    NSString *selectedBurnTime = burnTimeNamesArr[(int)sender.value*2+1];
    burningTimeLabel.text = selectedBurnTime;
    //newConversationBurnNoticeTime
    
    long burnTime = ((NSString*)burnTimeNamesArr[(int)sender.value*2]).intValue *60;
    [Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration = burnTime;
    /*
    if(!isBurningEnabled){
        [self OnOffClick:(UIButton*) [self viewWithTag:1]];
    }
    if(sender.value == 0)
    {
        [self OnOffClick:(UIButton*) [self viewWithTag:1]];
    }*/
    if ([self.delegate respondsToSelector:@selector(touchHappened)])
    {
        [self.delegate touchHappened];
    }
}
/*
-(void) OnOffClick:(UIButton*) button
{
    if(isBurningEnabled)
    {
        [button setTitle:@"Off" forState:UIControlStateNormal];
        [slider setThumbImage:burnOffImage forState:UIControlStateNormal];
        isBurningEnabled = NO;
        [Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration = 0;
    } else
    {
        [button setTitle:@"On" forState:UIControlStateNormal];
        [Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration = savedSliderValue;
        if([Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration <= 0)
        {
            [Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration = 60;
            savedSliderValue = 60;
        }
        [slider setThumbImage:burnOnImage forState:UIControlStateNormal];
        isBurningEnabled = YES;
    }
    [self.burnSliderDelegate burnSliderValueStatusChanged];
    [button setNeedsDisplay];
}*/

@end
