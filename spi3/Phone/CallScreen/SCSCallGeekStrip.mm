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
//  SCSCallGeekStrip.m
//  SPi3
//
//  Created by Eric Turner on 3/17/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSCallGeekStrip.h"
#import "SCPCall.h"
#import "SCPCallbackInterface.h"

// Geek strip
void *findGlobalCfgKey(const char *key);
int getMediaInfo(int iCallID, const char *key, char *p, int iMax);
void t_save_glob();
static int *piShowGeekStrip;

@implementation SCSCallGeekStrip

- (void)updateWithCall:(SCPCall *)aCall {
//    if (!self.canShow)
//        return;
    [self _updateWithCall:aCall];
}

- (void)_updateWithCall:(SCPCall *)aCall {
    NSString *str = nil;
    char buf[64];
    int r=getMediaInfo(aCall.iCallId,"codecs",&buf[0],63);
    if(r<0)r=0;
    if(r>0) str = [NSString stringWithUTF8String:&buf[0]];
    
    self.text = str;
}

// @see g_cfg.cpp iShowGeekStrip
- (BOOL)lastSavedShowing {
    return (BOOL)(piShowGeekStrip && *piShowGeekStrip);
}

- (void)saveLastDisplayState:(BOOL)isShowing {
    if (piShowGeekStrip == NULL)
        piShowGeekStrip = (int *)findGlobalCfgKey("iShowGeekStrip");
    
    if(*piShowGeekStrip != isShowing) {
        piShowGeekStrip[0]=!piShowGeekStrip[0];
        t_save_glob();
    }
}

#pragma mark - Accessibility

- (NSString *)accessibilityLabel {
    return [self voiceOverString];
}

/*
 * Space delimited string parts:
 * [0] RTT -> 55 (wiki: NAT absence: server; presence: relay (deduce by count of componenets))
 * [1] seconds of media in the queue -> 0.4
 * [2] % packet loss  -> 0.2%
 * [3] 'Loss' (the suffix for packet loss value)
 * [4] codec, possibly with CN (comfort noise) -> GSM/CN
 * [5] UNKNOWN: sometimes shows '1', where codec may include '/CN' or not.
 *
 * wiki example: "55 0.4 0.2% Loss GSM/CN"
 *
 * NOTE:
 * https://wiki.silentcircle.org/pages/viewpage.action?spaceKey=QA&title=Silent+Phone+Geek+Strip
 * wiki says 1st value is NAT, but it appears to be Round Trip Time - assume always present.
 *
 * - assume space-delimited string will always have >= 4 parts
 * - handle assumption variant as unknown format
 *
 * OBS: "106 BB1.9- 0.0% Loss G.722 1" __ "106 bb0.5+ 0.1% Loss G.722 1" __ "4 0.3+ 0.1% Loss G.722/CN 1"
 * OBS: additional char after [0] e.g. 'b'.
 */
- (NSString *)voiceOverString {
    NSString *lbTxt = self.text;
    NSArray *parts = [lbTxt componentsSeparatedByString:@" "];
    if (!parts || parts.count < 1)
        return nil;
    
    // Best effort for unknown format
    // Simply join space-delimited substrings with commas
    NSString *txt = [parts componentsJoinedByString:@", "];
    
    BOOL unrecognizedFormat = (parts.count < 5);
    if (unrecognizedFormat)
        return txt;
    
    NSString *rtt    = [NSString stringWithFormat:@"%@. ", parts[0]];
    NSString *q      = [NSString stringWithFormat:@"%@. ", parts[1]];
    NSString *pkLoss = [NSString stringWithFormat:@"%@ %@. ", parts[2], parts[3]];
    NSString *codec  = parts[4];
    // split codec on '/' to get potential 'CN' part
    NSArray *codecparts = [codec componentsSeparatedByString:@"/"];
    if (codecparts.count > 1) {
        codec = [NSString stringWithFormat:@"%@, %@. ", codecparts[0], codecparts[1]];
    } else {
        [NSString stringWithFormat:@"%@. ", parts[4]];
    }
    
    // additional string parts? Concat with comma delimiters.
    NSString *addtl  = nil;
    if (parts.count > 5) {
        if (parts.count > 6) {
            NSArray *subparts = [parts subarrayWithRange:NSMakeRange(5, parts.count-1)];
            addtl = [subparts componentsJoinedByString:@", "];
        } else {
            addtl = parts[5];
        }
    }
    
    txt = [NSString stringWithFormat:@"%@%@%@%@%@", rtt, q, pkLoss, codec, (addtl)?:@""];
    
    return NSLocalizedString(txt, txt);
}


@end
