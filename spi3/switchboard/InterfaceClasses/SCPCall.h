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
//  SCPCall.h
//  SilentConference
//
//  Created by Eric Turner on 5/9/15.
//  Based on original work by mahboud on 11/15/13.
//  Copyright (c) 2013 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


/**
 * This class is the call model object for use in the UI.
 *
 * Note that the VoIP engine uses C++ call objects internally which
 * instances of this class do not reference. SCPCall objects are created,
 * (generally) updated, and destroyed by the SCPCallManager
 * handleFncCallback:ph:iCallID:msgid:ns: callback function.
 */
@interface SCPCall : NSObject{
    @public int iReplaceSecMessage[2];
}

@property(strong, atomic)UILocalNotification* incomingCallNotif;
@property(strong, atomic)UILocalNotification* activeCallNotif;

#pragma mark - Call data
@property (copy, atomic) NSString *bufDialed;
@property (copy, atomic,readonly) NSString *bufPeer; //this is uuid as well, but it will be prefered-alias later(from sip-server)
@property (copy, atomic,readonly) NSString *bufAssertedID;
@property (copy, atomic) NSString *bufDstUUID;//can be nil

@property (copy, atomic) NSString *bufServName;
@property (copy, atomic) NSString *bufMsg;

@property (copy, atomic) NSString *priority;//from SIP packet, can be nil
@property(nonatomic, readonly, getter=getIsEmergency)BOOL isEmergency;//from SIP packet



// 03/31/16
@property (assign, atomic, getter=isInUse) BOOL inUse;

//05/12/15
@property (assign, nonatomic) BOOL shouldNotAddMissedCall;

/**
 * Set by phone service on <code>eIncomCall</code> and on <code>eCalling</code> callback messages.
 */
@property (assign, atomic) int iCallId;

/**
 * String "callid" of SIP session
 */
@property (copy, atomic) NSString *SIPCallId;

/**
 * Set by phone service on <code>eIncomCall</code> and on <code>eCalling</code> callback messages.
 */
@property void* pEng;

/**
 * Unique call identifier generated from uuid
 */
@property (copy, atomic) NSString *uniqueCallId;

/**
 * Keeps the image to reduce re-computations
 */
@property (strong, nonatomic) UIImage *callerImage;


#pragma mark - Start/Duration/End/TTL Times
/**
 * Set by phone engine to current system time if the call started (eStartCall).
 */
@property (assign, atomic) time_t startTime; //seconds since 1970 reference date

/**
 * @returns call duration in ms, computed as uiStartTime - endTime.
 */
@property (nonatomic, readonly) time_t duration;

/**
 * @return iDuration as formatted string: hrs:min
 */
@property (nonatomic, readonly, copy) NSString *durationString;

/**
 * Set by phone engine to current system time when the call is marked ended
 * @see
 */
@property (assign, atomic) time_t endTime; //seconds since 1970 reference date


#pragma mark - Call State
/**
 * This property means a peer-originated call.
 * Set to true by phone engine if incoming call detected (eIncomCall).
 */
@property (assign, atomic) BOOL isIncoming;

/**
 * @return startTime > 0.
 */
@property (readonly, nonatomic) BOOL isAnswered;

/**
 * @return endTime > 0. Use this accessor instead of iEnded to determine
 * if call was ended. Use iEnded to determine which side ended the call.
 * @see SCPCall iEnded
 */
@property (readonly, nonatomic) BOOL isEnded;

/**
 * Set by phone engine:
 * 0 > call not ended
 * 1 > ended by self user
 * 2 > ended by peer user
 *
 * @see scsEndCallUser enum
 * Set in SPCallManager
 */
@property (assign, atomic) int iEnded;

/**
 * True if call is on hold
 */
@property (assign, atomic, getter=isOnHold) BOOL onHold;

/**
 * Set to true if microphone is muted, managed by call window.
 */
//@property BOOL iMuted; we have to move this to the phone state


@property (assign, atomic) BOOL isInConference;

@property (assign, atomic) BOOL sipHasErrorMessage;

@property (assign, atomic) BOOL shouldShowVideoScreen;
@property (assign, atomic) BOOL userDidPressVideoButton;//we should not show answer video button if this is true
@property (copy, atomic) NSString *callType; // "audio" or "audio video"

#pragma mark - Security State
/**
 * Security via SDES not via ZRTP
 */
@property (assign, atomic) BOOL sdesActive; // unused??
@property (copy, atomic) NSString *zrtpWarning;
@property (copy, atomic) NSString *zrtpPEER;
@property (copy, atomic) NSString *nameFromAB;//  from phoneBook  or sip
@property (copy, atomic) NSString *nameFromWeb;
@property (copy, atomic) NSString *alias;

@property (copy, atomic) NSString *bufSAS;
@property (copy, atomic) NSString *bufSecureMsg;
@property (copy, atomic) NSString *bufSecureMsgV;//video

//@property (assign, atomic) BOOL	iShowVerifySas;
@property (assign, atomic, getter=isSASVerified) BOOL sasVerified;

//04/13/16 - returns YES for SAS phrase string > 4 chars, which is the
// minimum SAS string length
@property (readonly, nonatomic) BOOL hasSAS;

@property (nonatomic) BOOL isPSTN;
@property (nonatomic) BOOL hasQueuedVideoRequest;

@property (assign, atomic) BOOL didRecv180;
@property (assign, atomic) int iSIPErrorCode;

/**
 Returns the duration string for a given duration (time_t).
 
 The duration string contains leading zeroes and has the form of XX:XX for a duration less than an hour
 and of XX:XX:XX for a duration more than an hour.
 
 @param duration The duration variable in time_t
 @return The duration string
 */
+(NSString*)durationStringForCallDuration:(time_t)duration;

-(BOOL)hasVideo;
-(BOOL)isSCGreenSecure;
-(BOOL) isIncomingRinging;
-(NSString*)getName;//will return name from AB or SIP ir number
-(NSString*)displayNumber;//DID or username or alias
-(void)setBufPeer:(NSString*)ns;
-(UIColor *)getSecureColor;

-(int)getCallInfoByKey :(char *)key p:(char *)p iMaxLen:(int)iMaxLen;
-(int)setSecurityLabel:(UILabel *)lb desc:(UILabel *)lbDesc withBackgroundView:(UIView *) view;

-(BOOL)isSecure;
-(BOOL)isInProgress;  // these are ringing calls, dialing calls, calls that have not yet been answered
-(BOOL)isAnswered;	  // these are calls that are answered. They may be onhold
- (BOOL)isOCA;

- (NSString *)callInfoForKey:(NSString *)key;

- (void)clearState;

- (BOOL)isEqual:(id)object;

@end
