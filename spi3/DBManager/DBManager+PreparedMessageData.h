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
//  DBManager+PreparedMessageData.h
//  SPi3
//
//  Created by Gints Osis on 25/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "DBManager.h"
/*
 Category for handling each device status for sent message data
 
 Each sent message status update called from receiveAxoMsg includes deviceId
 for which we can detect message status for each sent device
 
 this is displayed in chat messages info menucontroller option. At the bottom of  info Alertcontroller
 */
@interface DBManager (PreparedMessageData)

/*
 Ask Zina prepareMessage data structure using formatted message data
 
 @return - NSArray of NSDictionaries containing device info and status for that device
 
 NSDictionary structure:
 transportId - transport id of message
 deviceName - name of sent device
 msgState - number of message status casted to scsMessageStatus, after creating preparedMessageData this will always be 0
 deviceId - deviceId
 */
-(NSArray *) getPreparedMessageData:(NSString *) messageDescriptor attachmentDescriptor:(NSString *)attachmentDescriptor  attribs:(NSString *) attribs;



/*
 Update Passed ChatObject's PreparedMessageData property 
 with new status update  passed in attribs command
 
 userData is not used for now because only delivered and read statuses are being updated
 failed status is unprocessed yet
 
  NOTE: This functions doesn't save the changed chatobject
 */
-(ChatObject *) updateMessageStatusForChatObject:(ChatObject *) chatObject userData:(NSDictionary *) userData attribs:( NSDictionary *) attribs;
@end
