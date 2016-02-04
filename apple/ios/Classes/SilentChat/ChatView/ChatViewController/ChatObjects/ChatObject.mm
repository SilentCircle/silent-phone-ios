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
#define kContactImageOffsetFromvCard 20
#define kContactImageSize 60
#define kMinContentRectHeight 40
#define kMinContentRectWidth 100

#define kImageThumbnailHeight 160

#define kFailedThumbnail [UIImage imageNamed:@"FailedIcon.png"]
#define kReceivedFileError [UIImage imageNamed:@"recivedFileError.png"]
#define kSendFileError [UIImage imageNamed:@"sendFileError.png"]

#import "axolotl_glue.h"
#import "ChatObject.h"
#import "SP_FastContactFinder.h"
#import "UserContact.h"
#import "Utilities.h"

#import "SnippetGraphView.h"


@implementation ChatObject

-(id) init {
    if(self = [super init])
    {
        _dictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id) initWithText:(NSString*) text{
    if(self = [self init])
    {
        self.messageText = text;
        // calculate height for messageViewText
        // no limited height
        // default font
        // boundingRectWithSize returns CGRect which needs to be rounded ceil to get CGSize
        // if contentRect height is smaller than min tableview cell height set it to cell height
        
        CGRect expectedLabelRect = [text boundingRectWithSize:CGSizeMake([Utilities utilitiesInstance].screenWidth - 155.f, 9999.f)
                                                      options:NSStringDrawingUsesLineFragmentOrigin//(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                   attributes:@{NSFontAttributeName:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize]}
                                                      context:nil
                                    ];
        
        
        //    CGFloat fs ;
        //      CGSize expectedLabelRect = [text sizeWithFont:[[Utilities utilitiesInstance] getFontWithSize:14] minFontSize:14 actualFontSize:&fs forWidth:screenWidth - 150 lineBreakMode:UILineBreakModeWordWrap ];
        
        
        CGSize expectedLabelSize = CGSizeMake(ceilf(expectedLabelRect.size.width), ceilf(expectedLabelRect.size.height));
        
        //expectedLabelSize.height += 20;
        
        expectedLabelSize.width += 20/2;//add font width/2
        expectedLabelSize.height += 14/2;//add font height/2
        
        if(expectedLabelSize.height < kMinContentRectHeight)
            expectedLabelSize.height = kMinContentRectHeight;
        
        if(expectedLabelSize.width< kMinContentRectWidth)
            expectedLabelSize.width = kMinContentRectWidth;
        
        
        
        /*
         if(expectedLabelSize.height > 50)
         expectedLabelSize.height += 30;
         else
         expectedLabelSize.height += 20;
         */
        // temporary to fit burn info
        //  expectedLabelSize.width += 20;
        
        // set imageName to empty string to Save in database
        //        _imageName = @"";
        
        // set message as already readed
        // if message is received and unread, reset this value to -1 after initialization
        // add observer for isRead value of -1
        _isRead = 0;
        self.contentRectValue = [NSValue valueWithCGSize:expectedLabelSize];
    }
    return self;
}

-(void) takeTimeStamp
{
    /*
     //  NSDate *currentTime = [NSDate date];
     NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
     [dateFormatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
     NSTimeZone *timeZone = [NSTimeZone systemTimeZone];
     NSDate *localNow = [NSDate dateWithTimeIntervalSinceNow: -timeZone.secondsFromGMT];*/
    
    _unixTimeStamp = time(NULL);
    
    [_dictionary setValue:[NSString stringWithFormat:@"%li",_unixTimeStamp] forKey:@"unixTimeStamp"];
    
    
    //  _unixTimeStamp = [localNow timeIntervalSince1970];
    // [_dictionary setValue:[NSString stringWithFormat:@"%li",_unixTimeStamp] forKey:@"timeStamp"];
}


-(id) initWithImage:(UIImage*) image{
    if(self = [self init])
    {
        _dictionary = [[NSMutableDictionary alloc] init];
        _image = image;
        
        // scale down image to get the thumbnail,
        // multiply scale by screen scale
        // divide content rect screen scale
        int scaleMultiplier = [UIScreen mainScreen].scale;
        
        int imageHeight;
        int imageWidth;
        if(image.size.height > kImageThumbnailHeight)
        {
            imageHeight = kImageThumbnailHeight;
        } else
        {
            imageHeight = image.size.height;
            
        }
        if(image.size.width > [Utilities utilitiesInstance].screenWidth - 155)
        {
            imageWidth = [Utilities utilitiesInstance].screenWidth - 155;
        } else
        {
            imageWidth = image.size.width;
        }
        
        _imageThumbnail = [self scaleImage:image ToSize:CGSizeMake([Utilities utilitiesInstance].screenWidth*scaleMultiplier, imageHeight*scaleMultiplier)];
        
        //screenwith - 155
        _contentRectValue = [NSValue valueWithCGSize:CGSizeMake(imageHeight/2 * image.size.width / image.size.height, imageHeight/2)];
        
        
        // set empty text, so TableViewController could seperate between text or image
        self.messageText = @"";
        //[self takeTimeStamp];
    }
    return self;
}
/*
-(id) initWithContact:(UserContact*) contact{
    if(self = [self init])
    {
        self.contentRectValue = [NSValue valueWithCGSize:kVcard.size];
        
        // draw contact image inside vCard
        UIGraphicsBeginImageContext(kVcard.size);
        [kVcard drawInRect:CGRectMake(0, 0, kVcard.size.width, kVcard.size.height)];
        [contact.contactImage drawInRect:CGRectMake(kContactImageOffsetFromvCard,kContactImageOffsetFromvCard, kContactImageSize,kContactImageSize)];
        UIImage *contactImageInVcard = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        self.contactImageInVcard = contactImageInVcard;
        
        //assign contact info
        _contact = contact;
        //[self takeTimeStamp];
    }
    return self;
}*/

-(id) initWithAttachment:(SCAttachment *)attachment {
    if(self = [self init])
    {
        self.attachment = attachment;
        self.imageThumbnail = [attachment thumbnailImage];
        /*
         NSString *waveForm = [attachment.metadata objectForKey:@"Waveform"];
         
         
         if(waveForm)
         {
         _isAudioAttachment = YES;
         NSData *waveFormData = [[NSData alloc] initWithBase64EncodedString:waveForm options:0];
         NSString *waveDuration = [attachment.metadata objectForKey:@"Duration"];
         self.imageThumbnail = [SnippetGraphView thumbnailImageForWaveForm:waveFormData duration:[NSNumber numberWithDouble:waveDuration.doubleValue] frameSize:CGSizeMake([Utilities utilitiesInstance].screenWidth, kMinContentRectHeight) color:[UIColor blackColor]];
         }
         */
        // set empty text, so TableViewController could seperate between text or image
        _messageText = @"";
        //[self takeTimeStamp];
    }
    return self;
}

-(void)checkWaveFormWithColor:(UIColor *) waveFormColor{
    if(!_attachment || !_attachment.metadata )return;
    

    NSString *waveForm = [_attachment.metadata objectForKey:@"Waveform"];
    if(waveForm)
    {
        _isAudioAttachment = YES;
        NSData *waveFormData = [[NSData alloc] initWithBase64EncodedString:waveForm options:0];
        NSString *waveDuration = [_attachment.metadata objectForKey:@"Duration"];
        const int kMinBurnLocationImageW = 40;
        self.imageThumbnail = [SnippetGraphView thumbnailImageForWaveForm:waveFormData duration:[NSNumber numberWithDouble:waveDuration.doubleValue] frameSize:CGSizeMake([Utilities utilitiesInstance].screenWidth/3*2 - kMinBurnLocationImageW, kMinContentRectHeight) color:waveFormColor];
        if (waveDuration) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"mmss"
                                                                   options:0
                                                                    locale:[NSLocale currentLocale]];
            formatter.locale = [NSLocale currentLocale];
            _audioLength = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: waveDuration.doubleValue]];
        }
    }
    
}

- (void)deleteAttachment {
	if (!_attachment)
		return;
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:_attachment.cloudLocator keyString:_attachment.cloudKey fyeo:NO segmentList:_attachment.segmentList];
	[scloud clearCache];
}

#pragma mark setters for properties
-(void)setmessageText:(NSString *)messageText
{
    _messageText = messageText;
    [_dictionary setValue:messageText forKey:@"messageText"];
}

-(void)setContactName:(NSString *)contactName
{
    _displayName = [[Utilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO];
    _contactName = [[Utilities utilitiesInstance] addPeerInfo:contactName lowerCase:YES];
    [_dictionary setValue:_contactName forKey:@"contactName"];
}

/*
 -(void)setContentRectValue:(NSValue *)contentRectValue
 {
 _contentRectValue = contentRectValue;
 
 NSString *frameString = NSStringFromCGRect(contentRectValue.CGRectValue);
 
 [_dictionary setValue:frameString forKey:@"contentRectValue"];
 }*/

-(void)setHasFailedAttachment:(int)hasFailedAttachment
{
    _hasFailedAttachment = hasFailedAttachment;
    if(hasFailedAttachment == 1)
    {
        if(_isReceived == 1)
        {
            self.imageThumbnail = kReceivedFileError;
        } else
        {
            self.imageThumbnail = kSendFileError;
        }
    }
    /*if(hasFailedAttachment == 1)
    {
        self.imageThumbnail = kFailedThumbnail;
    }*/
    [_dictionary setValue:[NSString stringWithFormat:@"%i",_hasFailedAttachment] forKey:@"hasFailedAttachment"];
    
}

-(void)setUnixTimeStamp:(long)unixTimeStamp
{
    _unixTimeStamp = unixTimeStamp;
    [_dictionary setValue:[NSString stringWithFormat:@"%li",unixTimeStamp] forKey:@"unixTimeStamp"];
}

-(BOOL)getIsFailed
{
    if(_isReceived==1 || _isSynced){
        return NO;
    }
    if(_messageIdentifier == 0 && _iSendingNow == 0)
    {
        return YES;
    }
    else if(_messageIdentifier != 0  && (_messageStatus < 0 || _messageStatus >= 400))
    {
        return YES;
    }
    return NO;
}

-(void)setIsReceived:(int)isReceived
{
    _isReceived = isReceived;
    if(_attachment)
    {
        if(isReceived == 1)
        {
            [self checkWaveFormWithColor:[UIColor blackColor]];
        }
        else
        {
            [self checkWaveFormWithColor:[UIColor whiteColor]];
        }
    }
    [_dictionary setValue:[NSString stringWithFormat:@"%i",isReceived] forKey:@"isReceived"];
}

-(void)setErrorString:(NSString *)errorString
{
    _errorString = errorString;
    [_dictionary setValue:errorString forKey:@"errorString"];
}


-(void)setID:(long)ID
{
    _ID = ID;
    [_dictionary setValue:[NSString stringWithFormat:@"%li",ID] forKey:@"ID"];
}

-(void)setMessageIdentifier:(long long)messageIdentifier
{
    _messageIdentifier = messageIdentifier;
    [_dictionary setValue:[NSString stringWithFormat:@"%lli",messageIdentifier] forKey:@"messageIdentifier"];
    
}

-(void)setIsSynced:(BOOL)isSynced
{
    _isSynced = isSynced;
    [_dictionary setValue:[NSNumber numberWithBool:isSynced] forKey:@"isSynced"];
}
-(void)setMEssageStatus:(long)messageStatus
{
    _messageStatus = messageStatus;
    [_dictionary setValue:[NSString stringWithFormat:@"%li",messageStatus] forKey:@"messageStatus"];
}


-(void)setIsRead:(int)isRead
{
    if(isRead == 1 && !self.unixReadTimeStamp){
        self.unixReadTimeStamp = time(NULL);
    }
    _isRead = isRead;
    [_dictionary setValue:[NSString stringWithFormat:@"%i",isRead] forKey:@"isRead"];
    
}
-(void) setUnixReadTimeStamp:(long) unixTimeStamp
{
    _unixReadTimeStamp = unixTimeStamp;
    [_dictionary setValue:[NSString stringWithFormat:@"%li",unixTimeStamp] forKey:@"unixReadTimeStamp"];
}

-(void)setBurnTime:(long)burnTime
{
    _burnTime = burnTime;
    [_dictionary setValue:[NSString stringWithFormat:@"%li",burnTime] forKey:@"burnTime"];
}

-(void)setLocation:(CLLocation *)location
{
    _location = location;
    
    NSMutableDictionary *locationDictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                               [NSString stringWithFormat:@"%f",location.coordinate.latitude], @"latitude",
                                               [NSString stringWithFormat:@"%f",location.coordinate.longitude], @"longitude",
                                               [NSString stringWithFormat:@"%f",location.altitude], @"altitude",
                                               [NSString stringWithFormat:@"%f",location.horizontalAccuracy], @"horizontalAccuracy",
                                               [NSString stringWithFormat:@"%f",location.verticalAccuracy], @"verticalAccuracy",
                                               nil];
    
    [_dictionary setValue:locationDictionary forKey:@"location"];
}

-(void)setmsgId:(NSString *)msgId
{
    _msgId = msgId;
    
    if(_msgId == nil){
        char buf[64];
        CTAxoInterfaceBase::generateMsgID("", buf, sizeof(buf));
        _msgId = [NSString stringWithUTF8String:buf];
    }
    
    // add msgid to allchatobjects hashtable
    [[Utilities utilitiesInstance].allChatObjects setObject:self forKey:msgId];
    
    [_dictionary setValue:_msgId forKey:@"msgId"];
    
    CTAxoInterfaceBase::uuid_sz_time(_msgId.UTF8String, &_timeVal);
}

-(void)setAttachmentName:(NSString *)attachmentName {
    _attachmentName = attachmentName;
    [_dictionary setValue:attachmentName forKey:@"attachment"];
}

-(void)setAttachment:(SCAttachment *)attachment {
	_attachment = attachment;
	[_dictionary setValue:attachment.cloudLocator forKey:@"cloudLocator"];
	[_dictionary setValue:attachment.cloudKey forKey:@"cloudKey"];
	[_dictionary setValue:attachment.segmentList forKey:@"segmentList"];
}

-(void)setImageThumbnail:(UIImage *)imageThumbnail {
    
    _imageThumbnail = imageThumbnail;
    
    // take two times smaller imagethumbnail frames for pictures
    if(_isAudioAttachment)
    {
        _contentRectValue = [NSValue valueWithCGSize:CGSizeMake(_imageThumbnail.size.width, _imageThumbnail.size.height)];
    } else
    {
        
        if(!_imageThumbnail){
            //TODO set default tumbnail
             //_imageThumbnail = kFailedThumbnail;
            //_messageText = @"Failed attachment";
            _contentRectValue = [NSValue valueWithCGSize:CGSizeMake(87, 87)];
            return;
        }
        
        CGFloat x = _imageThumbnail.size.width/[UIScreen mainScreen].scale;
        CGFloat y = _imageThumbnail.size.height/[UIScreen mainScreen].scale;
        
        CGFloat scale = 1.0f;
        
        
        if(x * 2 > [Utilities utilitiesInstance].screenWidth){
            scale = [Utilities utilitiesInstance].screenWidth / x / 2;
        }
        if(y * 2 > [Utilities utilitiesInstance].screenHeight){
            CGFloat scaley = [Utilities utilitiesInstance].screenHeight / y / 2;
            if(scaley < scale )scale = scaley;
        }
        
        _contentRectValue = [NSValue valueWithCGSize:CGSizeMake(x * scale, y * scale)];
    }
    
}

#pragma mark UIIMAge scaling
/**
 Scale image to Size
 @param image - image to resize
 @param targetSie - Size to resize to
 **/
- (UIImage *)scaleImage:(UIImage*) image ToSize:(CGSize)targetSize {
    
    UIImage *sourceImage = image;
    UIImage *newImage = nil;
    
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    
    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {
        
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor < heightFactor)
            scaleFactor = widthFactor;
        else
            scaleFactor = heightFactor;
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        if (widthFactor < heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        } else if (widthFactor > heightFactor) {
            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
        }
    }
    UIGraphicsBeginImageContext(targetSize);
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    //  thumbnailRect.origin.y = 0;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    [sourceImage drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage ;
}
/*
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    float imageWidth = image.size.width;
    float imageHeight = image.size.height;
    
    float ratio = imageWidth/imageHeight;
    
    float newHeight = newSize.height;
    float newWidth = newHeight/ratio;
    
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}*/

/*
 - (UIImage *)thumbnailImageForAudioWithFrame:(CGSize) frameSize Sizecolor: (UIColor *) color
 {
 UIImage *image = NULL;
 if(_waveForm)
 {
 NSData* waveData = _waveForm;
 
 NSUInteger pointsInArray = waveData.length;
 uint8_t  *graphPoints = (UInt8*)waveData.bytes;
 
 float graphHeight = frameSize.height -10  ;  // no margin on height
 
 float leftMargin = 10;
 float rightMargin = 10;
 float graphDurationtMargin = 10;    // between graph and duration
 float maxGraphPoints = 60;
 
 NSString* durationText = @"00:00";
 
 if(_waveDuration)
 {
 NSDateFormatter* durationFormatter =  [SCDateFormatter localizedDateFormatterFromTemplate:@"mmss"];
 durationText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: _waveDuration.doubleValue]];
 }
 
 UIFont *titleFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
 
 NSMutableParagraphStyle *titleStyle = [[NSMutableParagraphStyle alloc] init];
 titleStyle.lineBreakMode = NSLineBreakByTruncatingTail;
 titleStyle.alignment = NSTextAlignmentCenter;
 
 NSDictionary *attributes = @{
 NSFontAttributeName: titleFont,
 NSParagraphStyleAttributeName: titleStyle,
 NSForegroundColorAttributeName: color,
 };
 
 CGSize textRectSize = [durationText sizeWithAttributes:attributes];
 
 float graphPointsWidth = pointsInArray < maxGraphPoints ? maxGraphPoints : pointsInArray;
 float frameWidth = leftMargin + graphPointsWidth + graphDurationtMargin + textRectSize.width + rightMargin;
 
 // correct if calulated width is larger than what we asked for
 if(frameWidth > frameSize.width)
 {
 float diff = frameWidth - frameSize.width;
 graphPointsWidth -=diff;
 frameWidth -=diff;
 }
 
 CGSize newFrameSize = (CGSize) { .width = frameWidth,
 .height = frameSize.height};
 
 CGRect textRect = (CGRect){
 .origin.x = frameWidth- textRectSize.width - leftMargin,
 .origin.y = (newFrameSize.height - textRectSize.height ) / 2,      // I want text vert centered
 .size.width = textRectSize.width,
 .size.height = textRectSize.height + 5
 };
 
 float graphWidth  = frameWidth - rightMargin - graphDurationtMargin  - textRectSize.width - leftMargin;
 
 CGRect graphRect = (CGRect){
 .origin.x = leftMargin,
 .origin.y =  (newFrameSize.height - graphHeight)/2,
 .size.width = graphWidth,
 .size.height = graphHeight
 };
 
 
 UIGraphicsBeginImageContextWithOptions(newFrameSize, NO, 0);
 
 
 // draw the duration text
 [durationText drawInRect:textRect withAttributes:attributes];
 
 CGMutablePathRef graphPath = CGPathCreateMutable();
 for (int k = 0; k < pointsInArray; k++)
 {
 uint8_t sample = graphPoints[k];
 
 //              sample = k*2;  // debugging
 
 CGFloat height = (sample / 255.0) * graphRect.size.height;
 CGFloat xloc = graphRect.origin.x +   (graphPointsWidth / pointsInArray )  * k ;
 
 CGPathMoveToPoint (graphPath, nil, xloc, graphRect.origin.y+ (graphRect.size.height / 2) - height/2.0);
 CGPathAddLineToPoint (graphPath, nil, xloc, graphRect.origin.y+ (graphRect.size.height / 2) - height/2.0 + height );
 }
 
 CGContextRef context = UIGraphicsGetCurrentContext();
 CGContextSetShouldAntialias (context, NO);
 CGContextSetLineWidth(context,0.5);
 CGContextSetAlpha(context, 1.0);
 
 CGContextSetStrokeColorWithColor(context,  color.CGColor);
 CGContextAddPath(context, graphPath);
 CGContextStrokePath(context);
 
 image = UIGraphicsGetImageFromCurrentImageContext();
 UIGraphicsEndImageContext();
 CGPathRelease(graphPath);
 
 }
 
 return image;
 
 }*/
@end
