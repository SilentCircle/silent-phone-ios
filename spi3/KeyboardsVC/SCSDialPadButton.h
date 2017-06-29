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
//  SCSDialPadButton.h
//  SPi3
//
//  Created by Eric Turner on 12/12/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * This UIButton subclass is a convenience class for deriving dial pad
 * string and int values from an enclosing view containing the self
 * button instance, a title label, and a subtitle label.
 * The values are derived from the title label, a private outlet
 * property wired in IB.
 */
@interface SCSDialPadButton : UIButton

/**
 * The value of this property is used by the MainDialPadVC to add to the
 * call number string. The string values are 1 - 9, 0, *, and #.
 *
 * Note that the dialPadIntValue public property value is derived from
 * the private lbTitle outlet property text value. If the outlet is not
 * connected in IB, the string returned will be (null) and the integer
 * returned in dialPadIntValue will be undefined.
 *
 * @return The text value of the private lbTitle property.
 */
@property (copy, readonly, nonatomic) NSString *dialPadStringValue;

/**
 * This property exposes the string value of the subtitle label on a
 * dial pad button, e.g., "A B C", which is the subtitle of the
 * number 2 dial pad button. Only dial pad numbers 2 - 9 have subtitles.
 * The subtitle value is not currently used in this app, but this
 * property is included in this convenience class in case it is ever
 * needed.
 *
 * @return The text value of the private lbSubtitle property or an
 *         empty string if the lbSubtitle property is nil.
 */
@property (copy, readonly, nonatomic) NSString *dialPadStringSubtitle;

/**
 * The value of this property is used via the MainDialPadVC by
 * SPCallManager for DTMF tone generation. It expects an integer 0 - 11
 * representing a zero-based index into an array of 12 dial pad
 * buttons: 1 - 9, *, 0, and #.
 *
 * @return 0 - 8 for numbers 1 - 9,
 *         9 for "*",
 *         10 for "0", and
 *         11 for "#".
 */
@property (readonly, nonatomic) NSInteger dialPadIntValue;

@end
