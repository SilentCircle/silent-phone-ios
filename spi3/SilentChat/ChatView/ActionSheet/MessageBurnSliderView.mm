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

#import "MessageBurnSliderView.h"

#import "ChatUtilities.h"
#import "RecentObject.h"
#import "UserService.h"
#import "GroupChatManager.h"

#define kViewOffsetFromSides 10
#define kSliderThumbImage [UIImage imageNamed:@"BurnOnRedCircle.png"]
#define kBackgroundColor [UIColor colorWithRed:238/255.0f green:233/255.0f blue:222/255.0f alpha:1.0f]


@implementation MessageBurnSliderView
{
    BOOL isBurningEnabled;
    NSMutableArray *burnTimeNamesArr;
    
    UILabel *burningTimeLabel;
    
    UISlider *slider;
    UIImage *burnOffImage;
    UIImage *burnOnImage;
    
    float savedSliderValue;
    float _initialSlideValue;
    
    UILabel *burnValueLabel;
    
    UIView *burnValueBackgroundView;
}

-(id) initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        
        burnTimeNamesArr = [[ChatUtilities utilitiesInstance].allBurnValues mutableCopy];
        isBurningEnabled = YES;
        
        

        // if v1/me has not returned set the shortest burn time
        int maximumBurnSecs = 10080 * 60;
        if ([UserService currentUser].maximumBurnSecs) {
            maximumBurnSecs = [UserService currentUser].maximumBurnSecs.intValue;
        }
        
        // if saved burn time is bigger than allowed maximum at this time, set new saved burn time value to maximum allowed
        if ([ChatUtilities utilitiesInstance].selectedRecentObject.burnDelayDuration > maximumBurnSecs)
        {
            [ChatUtilities utilitiesInstance].selectedRecentObject.burnDelayDuration = maximumBurnSecs;
        }
        // remove burn values bigger than maximum burn time
        NSMutableArray *objectsToRemove = [[NSMutableArray alloc] init];
        for (int i = 0; i<burnTimeNamesArr.count; i+=2) {
            NSString *burnValueString = burnTimeNamesArr[i];
            if([burnValueString intValue] * 60 > maximumBurnSecs)
            {
                [objectsToRemove addObject:burnTimeNamesArr[i]];
                [objectsToRemove addObject:burnTimeNamesArr[i + 1]];
            }
        }
        
        for (int i = 0; i<objectsToRemove.count; i++)
        {
            [burnTimeNamesArr removeObject:objectsToRemove[i]];
        }
        
        
        /*
        UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(kViewOffsetFromSides, 0, [ChatUtilities utilitiesInstance].screenWidth - kViewOffsetFromSides*2, self.frame.size.height)];
        //[backgroundView setAlpha:0.4f];
        [backgroundView setBackgroundColor:[UIColor blackColor]];
        [self addSubview:backgroundView];
         backgroundView.layer.cornerRadius = 10;
         backgroundView.layer.masksToBounds = YES;
        */
        
        [self setBackgroundColor:[UIColor clearColor]];
        
        slider = [[UISlider alloc] initWithFrame:CGRectMake(5, 0, self.frame.size.width, self.frame.size.height)];
        slider.maximumValue = burnTimeNamesArr.count / 2 - 1;
        slider.continuous = YES;
        
        burnOffImage = [UIImage imageNamed:@"BurnOffForSlider.png"];
        burnOnImage = [UIImage imageNamed:@"BurnOnForSlider.png"];
        
        
        UIImage *sliderThumbImage = kSliderThumbImage;
        sliderThumbImage = [sliderThumbImage resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
        
        [slider setMinimumTrackTintColor:[UIColor redColor]];
        [slider setThumbImage:sliderThumbImage forState:UIControlStateNormal];
        [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
        [slider addTarget:self action:@selector(sliderTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
        [slider addTarget:self action:@selector(sliderTouchUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
        
        [self addSubview:slider];
        
        burnValueLabel = [[UILabel alloc] init];
        CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * 0.5);
        burnValueLabel.transform = trans;
        
        burnValueBackgroundView = [[UIView alloc] init];
        [burnValueBackgroundView setBackgroundColor:kBackgroundColor];
        trans = CGAffineTransformMakeRotation(M_PI * 0.5);
        burnValueBackgroundView.transform = trans;
        burnValueBackgroundView.layer.cornerRadius = 10;
        burnValueBackgroundView.layer.masksToBounds = YES;
        
        
        [self addSubview:burnValueBackgroundView];
        [self addSubview:burnValueLabel];
        
        [self setSliderToSelectedRecentPosition];
        [self registerNotifications];
    }
    
    return self;
}

-(void) registerNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recentObjectUpdated:) name:kSCSRecentObjectUpdatedNotification object:nil];
}

-(void) deRegisterNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSCSRecentObjectUpdatedNotification object:nil];
}

-(void) recentObjectUpdated:(NSNotification *) note
{
    RecentObject *updatedRecent = [note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    if (updatedRecent && [updatedRecent isEqual:[ChatUtilities utilitiesInstance].selectedRecentObject])
    {
        [[ChatUtilities utilitiesInstance].selectedRecentObject updateWithRecent:updatedRecent];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setSliderToSelectedRecentPosition];
        });
    }
}

-(void) setSliderToSelectedRecentPosition
{
    NSString *burnDelayString;
    
    burnDelayString =[NSString stringWithFormat:@"%li",[ChatUtilities utilitiesInstance].selectedRecentObject.burnDelayDuration/60];
    
    for (int i = 0; i < burnTimeNamesArr.count; i++) {
        NSString *thisValue = burnTimeNamesArr[i];
        if([thisValue isEqualToString:burnDelayString])
        {
            slider.value = i/2;
            burnValueLabel.text = burnTimeNamesArr[i+1];
            
            _initialSlideValue = slider.value;
            
            [self repositionBurnValueLabelToValue:slider.value animate:YES];
            break;
        }
    }
}

-(void) repositionBurnValueLabelToValue:(float) value animate:(BOOL)animate
{
    NSString *selectedBurnTime = burnTimeNamesArr[(int)value*2+1];
    slider.accessibilityValue = selectedBurnTime;
    burnValueLabel.text = selectedBurnTime;
    
    CGRect thumbFrame = [slider thumbRectForBounds:self.frame trackRect:[slider trackRectForBounds:slider.frame] value:slider.value];
    if(animate)
    {
        [burnValueLabel sizeToFit];
        [burnValueLabel setHidden:YES];
        [burnValueBackgroundView setFrame:CGRectMake(thumbFrame.origin.x - 5, 50, burnValueLabel.frame.size.width + 10,0)];
        [UIView animateWithDuration:0.1f animations:^(void)
        {
             [burnValueBackgroundView setFrame:CGRectMake(thumbFrame.origin.x - 5, 50, burnValueLabel.frame.size.width + 10, burnValueLabel.frame.size.height + 10)];
        } completion:^(BOOL finished){
            [burnValueLabel setHidden:NO];
            burnValueLabel.center = burnValueBackgroundView.center;
        }];
    } else
    {
        [burnValueLabel sizeToFit];
        [burnValueBackgroundView setFrame:CGRectMake(thumbFrame.origin.x - 5, 50, burnValueLabel.frame.size.width + 10, burnValueLabel.frame.size.height + 10)];
        burnValueLabel.center = burnValueBackgroundView.center;
    }
}

/**
 * handles touch in burnslider
 * when user touches burnslider, signal delegate(ChatViewController) to stop actionsheetview closing
 **/
- (void)sliderValueChanged:(UISlider *)sender {
    
    savedSliderValue = sender.value;
    
    [self repositionBurnValueLabelToValue:sender.value
                                  animate:NO];
}

- (void)sliderTouchUpInside:(UISlider *)sender {
    
    _initialSlideValue = sender.value;
    
    if(self.burnSliderDelegate && [self.burnSliderDelegate respondsToSelector:@selector(burnSliderValueChanged:)]) {
        
        long newBurnTime = ((NSString*)burnTimeNamesArr[(int)savedSliderValue*2]).intValue *60;

        [self.burnSliderDelegate burnSliderValueChanged:newBurnTime];
    }
}

- (void)sliderTouchUpOutside:(UISlider *)sender {

    slider.value = _initialSlideValue;
    
    [self repositionBurnValueLabelToValue:slider.value
                                  animate:NO];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if([keyPath isEqualToString:@"frame"]) {
        
        CGRect changedFrame = CGRectZero;
        
        if([object valueForKeyPath:keyPath] != [NSNull null]) {
            changedFrame = [[object valueForKeyPath:keyPath] CGRectValue];
        }
        
        CGRect frame;
        frame = self.frame;
        frame.origin.y = changedFrame.origin.y - self.frame.size.height;
        self.frame = frame;
    }
}

@end
