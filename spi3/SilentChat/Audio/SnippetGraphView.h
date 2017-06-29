//
//  SnippetGraphView.h
//  SnippetGraph
//
//  Created by mahboud on 6/5/14.
//  Copyright (c) 2014 BitsOnTheGo. All rights reserved.
//

//#import "Siren.h"

#import <UIKit/UIKit.h>


@interface SnippetGraphView : UIView
@property (nonatomic, strong) UIColor *waveColor;

- (void) addPoint:(CGFloat) newPoint;
- (void) setGraphWithNativePoints:(unsigned char *) points numOfPoints:(NSInteger) numOfPoints;
- (void) setGraphWithFloatPoints:(CGFloat *) points numOfPoints:(NSInteger) numOfPoints;
- (unsigned char *) getNativeGraphPoints: (NSInteger *) numPoints;
- (void) reset;


+ (UIImage *)thumbnailImageForWaveForm:(NSData *)waveData
							  duration:(NSNumber *)durationN
							 frameSize: (CGSize)frameSize
								 color: (UIColor *)color;

+ (UIImage *)thumbnailImageForVoiceMail:(NSString *)callerIDname
						 callerIDnumber:(NSString *)callerIDnumber
							   duration:(NSNumber *)durationN
							  frameSize:(CGSize)frameSize
								  color:(UIColor *)color;

@end
