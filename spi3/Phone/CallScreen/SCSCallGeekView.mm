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
//  SCSCallGeekView.m
//  SPi3
//
//  Created by Eric Turner on 3/17/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSCallGeekView.h"
#import "SCSCallGeekStrip.h"
#import "SCPCall.h"
#import "SCPCallbackInterface.h"

// LED
void *findGlobalCfgKey(const char *key);
int g_getCap(int &iIsCN, int &iIsVoice, int &iPrevAuthFail);
// Antenna
int getMediaInfo(int iCallID, const char *key, char *p, int iMax);


@interface SCSCallGeekView ()
@property (readonly, nonatomic) BOOL stripCanSpeak;
@property (readonly, nonatomic) BOOL isDim;
@end

@implementation SCSCallGeekView


// At start (on call screen) the LED should show dimmed and inactive.
// Antenna and geekStrip should be hidden.
- (void)configureStartingState {
    if (self.ledCanShow) {
        _ivLED.alpha = 0.5;
        _ivLED.hidden = NO;
    } else {
        [self showLED:NO];
    }
    [self showAntenna:NO];
    [self showGeekStrip:NO];
}


#pragma mark - Geek Strip

- (void)updateGeekStripWithCall:(SCPCall *)aCall {
    if (!self.geekStripCanShow)
        return;
    [self _updateGeekStripWithCall:aCall];
}

- (void)_updateGeekStripWithCall:(SCPCall *)aCall {
    NSString *str = nil;
    char buf[64];
    int r=getMediaInfo(aCall.iCallId,"codecs",&buf[0],63);
    if(r<0)r=0;
    if(r>0) str = [NSString stringWithUTF8String:&buf[0]];
    
    _lbStrip.text = str;
}

- (BOOL)geekStripCanShow {
//    return _lbStrip.canShow;
    return [self ledCanShow];
}

- (void)showGeekStrip:(BOOL)shouldShow {    
    if (_lbStrip.isHidden != shouldShow)
        return;
    _lbStrip.hidden = (shouldShow) ? !(self.geekStripCanShow) : YES;
}

- (BOOL)stripCanSpeak {
    return (self.geekStripCanShow && !_lbStrip.isHidden);
}

- (void)updateGeekDisplayState:(BOOL)shouldShow {
    [_lbStrip saveLastDisplayState:shouldShow];
}

- (BOOL)geekStripLastSavedShowing {
    return _lbStrip.lastSavedShowing;
}

#pragma mark - LED

- (void)updateLED {
    if (!self.ledCanShow || _ivLED.isHidden)
        return;
    [self _updateLED];
}

- (void)_updateLED {
    int iIsCn,iIsVoice,iPrevAuthFail;
    int v=g_getCap(iIsCn,iIsVoice,iPrevAuthFail);
    static int pv=-1;
    static int previPrevAuthFail=-1;
    float fv=(float)v*0.005f+.35f;
    
    if(previPrevAuthFail!=iPrevAuthFail || pv!=v){
        if(iPrevAuthFail){
            _ivLED.backgroundColor = [UIColor colorWithRed:fv green:0 blue:0 alpha:1.0];
        }
        else{
            _ivLED.backgroundColor = [UIColor colorWithRed:0 green:fv blue:0 alpha:1.0];
        }
        pv=v;
        previPrevAuthFail=iPrevAuthFail;
    }
}

// @see g_cfg.cpp iShowRXLed
- (BOOL)ledCanShow {
    static int *piShowRXLed = (int *)findGlobalCfgKey("iShowRXLed");
    return (BOOL)(piShowRXLed && *piShowRXLed);
}

- (void)showLED:(BOOL)shouldShow {
    // Dimmed in configureStartingState. Un-dim if needed.
    if (shouldShow && _ivLED.alpha < 1.) _ivLED.alpha = 1.;

    if (_ivLED.isHidden != shouldShow)
        return;
    _ivLED.hidden = (shouldShow) ? !(self.ledCanShow) : YES;
}

#pragma mark - Antenna

- (void)updateAntennaWithCall:(SCPCall *)aCall {
    char buf[32];
    strcpy(buf,"ico_antena_");
    static char cc;
    int r=getMediaInfo(aCall.iCallId,"bars",&buf[11],31-11);//11=strlen("ico_antena_" or buf);
    if(r==1){
        static int iX=0;
        iX++;
        if((cc!=buf[11]) || (iX&7)==1){
            cc=buf[11];
            UIImage *img = [UIImage imageNamed:[NSString stringWithUTF8String:&buf[0]]];
            // For later retrieval in antennaVoiceOver
            img.accessibilityIdentifier = [NSString stringWithFormat:@"%c",cc];
            _ivAntenna.image = img;
        }
    }
}

- (void)showAntenna:(BOOL)shouldShow {
    if (_ivAntenna.isHidden != shouldShow)
        return;
    _ivAntenna.hidden = !shouldShow;
}


#pragma mark - Accessibility

- (NSString *)accessibilityLabel {
    
    NSString *bars = [self antennaVoiceOver];
    
    if (!self.stripCanSpeak)
        return bars;
    
    NSMutableString *txt = [NSMutableString stringWithCapacity:32];
    
    NSString *gStrip = [_lbStrip voiceOverString];
    if (gStrip) {
        [txt appendString:[NSString stringWithFormat:@"%@. ",gStrip]];
    }
    [txt appendString:bars];
    
    return NSLocalizedString(txt, txt);
}

- (NSString *)antennaVoiceOver {
    int n = [(NSString*)_ivAntenna.image.accessibilityIdentifier intValue];
    if (n < 0 || n > 4)
        return nil;

    NSString *txt = [NSString stringWithFormat:@"%1$i bar%2$@", n, (n==1) ? @"" : @"s"];
    return NSLocalizedString(txt, txt);
}

@end
