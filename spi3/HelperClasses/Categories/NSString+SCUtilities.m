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
//  NSString+SCUtilities.m
//  SPi3
//
//  Created by Eric Turner on 7/22/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "NSString+SCUtilities.h"

@implementation NSString (SCUtilities)

+ (NSString *)intToBinary:(int)intVal {
    return [self intToBinary:intVal delimited:NO];
}

// http://iosdevelopertips.com/objective-c/convert-integer-to-binary-nsstring.html
// John Muchow solution
+ (NSString *)intToBinary:(int)intValue delimited:(BOOL)delim {
    int byteBlock = 8,    // 8 bits per byte
    totalBits = sizeof(int) * byteBlock, // Total bits
    binaryDigit = 1;  // Current masked bit
    
    // Binary string
    NSMutableString *binaryStr = [[NSMutableString alloc] init];
    
    do {
        // Check next bit, shift contents left, append 0 or 1
        [binaryStr insertString:((intValue & binaryDigit) ? @"1" : @"0" ) atIndex:0];
        
        if (delim) {
            // More bits? On byte boundary ?
            if (--totalBits && !(totalBits % byteBlock))
                [binaryStr insertString:@"|" atIndex:0];
        }
        
        // Move to next bit
        binaryDigit <<= 1;
        
    } while (totalBits);
    
    // Return binary string
    return binaryStr;
}

@end
