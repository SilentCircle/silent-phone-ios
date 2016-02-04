/*
Copyright (C) 2015, Silent Circle, LLC.  All rights reserved.

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

#import <CoreFoundation/CFDate.h>
#import <CoreGraphics/CoreGraphics.h>

#import "SCProgressView.h"

//06/30/15 colors per 150618_SC_BrandGuidelines_reducedsize.pdf
#define kProgressColor [UIColor colorWithRed:229.0/255.0 green:60.0/255.0 blue:48.0/255.0 alpha:1.0]
#define kDotColor [UIColor colorWithRed:84.0/255.0 green:84.0/255.0 blue:82.0/255.0 alpha:1.0]

static CFTimeInterval const kDotAnimDuration = (CFTimeInterval)1.2;
static NSTimeInterval const kInnerPulseDuration = 0.35;
static NSTimeInterval const kInnerPulseWaitDuration = 0.5;

@implementation SCProgressView
{
    CAShapeLayer *progressLayer;
    IBOutlet UIView *innerView;
    IBOutlet UIView *outerView;
    CGFloat _currProgress;
}


#pragma mark - Initialization/Setup

- (void)awakeFromNib {
    [self layoutOuterView];
    [self layoutInnerView];
    [self createProgressLayer];
}

- (void)createProgressLayer {
    
    CGFloat lineWidth = 4;
    CGRect bounds = CGRectIntegral(outerView.bounds);
    CGPoint centerPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidX(self.bounds));
    CGFloat radius = CGRectGetWidth(bounds)/2.0 + lineWidth/2;
    CGFloat startAngle = (CGFloat)(-M_PI_2);
    CGFloat endAngle   = (CGFloat)(M_PI_2 * 3);
    
    progressLayer = [[CAShapeLayer alloc] init];
    UIBezierPath *ring = [UIBezierPath bezierPathWithArcCenter:centerPoint 
                                                        radius:radius
                                                    startAngle:startAngle
                                                      endAngle:endAngle
                                                     clockwise:YES];
    progressLayer.path = ring.CGPath;
    progressLayer.backgroundColor = [UIColor clearColor].CGColor;
    progressLayer.fillColor = nil;
    progressLayer.strokeColor = kProgressColor.CGColor;
    progressLayer.lineWidth = lineWidth;
    progressLayer.lineCap = @"round";
    progressLayer.strokeStart = 0.0;
    progressLayer.strokeEnd = 0.0;
    [self.layer addSublayer:progressLayer];
    
    _currProgress = 0.0;
}

- (void)layoutOuterView {
    outerView.layer.cornerRadius = outerView.bounds.size.width/2;
}

- (void)layoutInnerView {
    for (UIView *view in innerView.subviews) {
        view.layer.cornerRadius = view.frame.size.width/2;
        view.backgroundColor = kDotColor;
    }
}


#pragma mark - Progress Update

- (void)setProgress:(CGFloat)progress {
    if (_currProgress >= 1.0 && progress >= 1.0) {
        _currProgress = 1.0;
//        NSLog(@"%s _currProgress: %1.2f - STOP dotsAnimation", __PRETTY_FUNCTION__, _currProgress);
        return;
    }
    
    if (progress < 0.0) {
        progress = 0.0;
    }
    if (progress > 1.0) {
        progress = 1.0;
    }
    
    progressLayer.strokeEnd = progress;
    _currProgress = progress;
}

- (NSString *)accessibilityValue {
    NSString *status = [NSString stringWithFormat:@"%d percent complete", (int)(_currProgress * 100)];
    return status;
}

#pragma mark - Dots Animation

- (void)startAnimatingDots {
    CFTimeInterval beginTime = CACurrentMediaTime();
    for (int i=0; i<innerView.subviews.count; i++) {
        CALayer *dotLayer = [(UIView*)innerView.subviews[i] layer];
        CAKeyframeAnimation *aniScale = [[CAKeyframeAnimation alloc] init];
        aniScale.keyPath = @"transform.scale";
        aniScale.values = @[@(1.0), @(1.6), @(1.0), @(1.0)];
        aniScale.removedOnCompletion = NO;
        aniScale.repeatCount = HUGE;
        aniScale.beginTime = beginTime - kDotAnimDuration + (CFTimeInterval)(i * 0.2);
        aniScale.keyTimes = @[@(0.0), @(0.2), @(0.4), @(1.0)];
        aniScale.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                     [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                     [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                     [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
                                     ];
        aniScale.duration = kDotAnimDuration;
        [dotLayer addAnimation:aniScale forKey:@"com.silentcircle.dotSpotify"];
    }
}

- (void)stopAnimatingDots {
    for (UIView *view in innerView.subviews) {
//        NSLog(@"  :: REMOVE all animations from dot %@", view);
        [view.layer removeAllAnimations];
    }    
}

- (void)pulseInnerView {
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.duration = kInnerPulseDuration;
    pulseAnimation.toValue = @(1.5);
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = 1.0;
    [innerView.layer addAnimation:pulseAnimation forKey:@"com.silentcircle.progressInnerViewPulse"];
}

- (void)successWithCompletion:(void (^)(void))completion {
    [self stopAnimatingDots];
    [self pulseInnerView];
    if (completion) {
        // dispatch after inner pulse animation duration and slight pause
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kInnerPulseWaitDuration * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           completion();
                       });
    }
}

- (void)resetProgress {
    progressLayer.strokeEnd = 0.0;
    [progressLayer removeAllAnimations];
}


#pragma mark - TESTING

/**
 * A test method to display a progress animation.
 *
 * Stops dots animation and then after a delay, starts dots animation
 * and calls animateProgress to display progress animation. Fire this
 * method from a button or similar event to test/tweak the progress
 * animation during development.
 *
 * @param sender The UI control which fires this method, e.g. a UIButton.
 *
 * @see animateProgress
 */
- (IBAction)testAnimation:(id)sender {
    [self stopAnimatingDots];
    [self resetProgress];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startAnimatingDots];
        [self animateProgress];
    });
}

/**
 * A testing utility which displays a linear progression of the stroke
 * animation over 5 seconds. The animationDidStop:finished: callback
 * will be invoked to simulate a successful progress event.
 *
 * Note: this method is compiled only in a DEBUG build.
 *
 * @see testAnimation:
 * @see animationDidStop:finished:
 */
- (void)animateProgress {
#ifdef DEBUG    
    progressLayer.strokeEnd = 0.0;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];    
    animation.fromValue = @(0.0);
    animation.toValue = @(1.0);
    animation.duration = 5.0;
    animation.delegate = self;
    animation.removedOnCompletion = NO;
    animation.additive = YES;
    animation.fillMode = kCAFillModeForwards;
    [progressLayer addAnimation:animation forKey:@"com.silentcircle.testProgressAnimation"];
#endif
}

/**
 * Animation delegate callback: displays the behavior of a successfull
 * progress completion, the same as with
 */
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    NSLog(@"%s animation stopped", __PRETTY_FUNCTION__);
    [self successWithCompletion:nil];
}

@end
