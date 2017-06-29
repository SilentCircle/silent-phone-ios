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
//  DBManager+Sorting.m
//  SPi3
//
//  Created by Gints Osis on 01/08/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//
#import "DBManager+Sorting.h"
@implementation DBManager (Sorting)
-(NSArray *) sort:(NSMutableArray *)arrayToSort
{
    NSArray *sortedArray = [arrayToSort sortedArrayUsingComparator:^(id obj1, id obj2) {
        
        ChatObject *chat1 = (ChatObject *) obj1;
        ChatObject *chat2 = (ChatObject *) obj2;
        //typedef NS_ENUM(NSInteger, NSComparisonResult) {NSOrderedAscending = -1L, NSOrderedSame, NSOrderedDescending};
        const long long usec_per_sec = 1000000;
        long long t1 = (long long)chat1.timeVal.tv_sec * usec_per_sec + (long long)chat1.timeVal.tv_usec;
        long long t2 = (long long)chat2.timeVal.tv_sec * usec_per_sec + (long long)chat2.timeVal.tv_usec;
        if(t1 > t2) return (NSComparisonResult)NSOrderedDescending;
        if(t1 < t2) return (NSComparisonResult)NSOrderedAscending;
        return (NSComparisonResult)NSOrderedSame;
    }];
    return sortedArray;
}
@end
