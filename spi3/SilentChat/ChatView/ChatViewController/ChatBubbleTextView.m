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
//  ChatBubbleTextView.m
//  SPi3
//
//  Created by Gints Osis on 23/09/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "ChatBubbleTextView.h"

@implementation ChatBubbleTextView

//
//  LinkedTextView.m
//
//  Created by Benjamin Bojko on 10/22/14.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Benjamin Bojko
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//
-(void) openUrl:(UITapGestureRecognizer *) recognizer
{
    UITextView *textView = self;
    CGPoint tapLocation = [recognizer locationInView:self];
    
    // we need to get two positions since attributed links only apply to ranges with a length > 0
    UITextPosition *textPosition1 = [textView closestPositionToPoint:tapLocation];
    UITextPosition *textPosition2 = [textView positionFromPosition:textPosition1 offset:1];
    
    // check if we're beyond the max length and go back by one
    if (!textPosition2) {
        textPosition1 = [textView positionFromPosition:textPosition1 offset:-1];
        textPosition2 = [textView positionFromPosition:textPosition1 offset:1];
    }
    
    // abort if we still don't have a string that's long enough
    if (!textPosition2) {
        return;
    }
    
    // get the offset range of the character we tapped on
    UITextRange *range = [textView textRangeFromPosition:textPosition1 toPosition:textPosition2];
    NSInteger startOffset = [textView offsetFromPosition:textView.beginningOfDocument toPosition:range.start];
    NSInteger endOffset = [textView offsetFromPosition:textView.beginningOfDocument toPosition:range.end];
    NSRange offsetRange = NSMakeRange(startOffset, endOffset - startOffset);
    
    if (offsetRange.location == NSNotFound || offsetRange.length == 0) {
        return;
    }
    
    if (NSMaxRange(offsetRange) > textView.attributedText.length) {
        return;
    }
    
    // now grab the link from the string
    NSAttributedString *attributedSubstring = [textView.attributedText attributedSubstringFromRange:offsetRange];
    NSURL *link = [attributedSubstring attribute:NSLinkAttributeName atIndex:0 effectiveRange:nil];
    
    if (!link) {
        return;
    }
    
    NSURL *URL = link;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:shouldInteractWithURL:inRange:)]) {
        // abort if the delegate doesn't allow us to open this URL
        if (![self.delegate textView:self shouldInteractWithURL:URL inRange:offsetRange]) {
            return;
        }
    }
    
    [[UIApplication sharedApplication] openURL:URL];
}
@end
