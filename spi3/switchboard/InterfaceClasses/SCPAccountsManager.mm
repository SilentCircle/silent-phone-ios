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
//  SCPAccountsManager.m
//  SP3
//
//  Created by Eric Turner on 5/14/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#ifndef NULL
#ifdef  __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif

#include "engcb.h"
#import "SCPAccountsManager.h"
#import "SCPAccountsManager_Private.h"


static int const MAX_ACCOUNTS = 20; // Arbitrary max count of accounts

SCPAccountsManager *SPAccountsManager = nil;

@implementation SCPAccountsManager


- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    
    SPAccountsManager = self;
    return self;
}

-(void *)activeAccounts{
    void *pp[MAX_ACCOUNTS];
    for(int i=0;i<MAX_ACCOUNTS;i++){
        pp[i]=getAccountByID(i,1);
    }
    return *pp;
}

- (NSInteger)countOfActiveAccounts {
    return [self accountsCountForIsActive:YES];
}

- (NSArray *)indexesOfUniqueAccounts {
    
    NSString *prevTitle = @"";
    
    NSMutableArray *a = [NSMutableArray array];
    
    int n = (int)[self countOfActiveAccounts];
    
    for (int i=0;i<n;i++){
        void *p = [self accountAtIndex:i];
        if(!p) continue;
        
        NSString * title = [self titleForAccount:p];
        
        if([title isEqualToString:prevTitle])continue;
        
        [a addObject:@(i)];
        
        prevTitle = title;
    }
    return [NSArray arrayWithArray:a];
}

- (BOOL)allAccountsOnline {
   int hasIP(void);
   
    BOOL ret =hasIP() && [self boolFromStrPtr:sendEngMsg(NULL,"all_online")];
    return ret;
}

- (BOOL)accountIsOn:(void *)acct {
    const char *state = sendEngMsg(acct,"isON");
    BOOL ret = [self boolFromStrPtr:state];
    return ret;
}

/**
 * Called by mainDialPadVC to display actionSheet of accounts selections.
 *
 * //TODO: fix count
 * NOTE: The first 2 accounts are redundant SilentCircle accounts, which are
 * really the same account twice. Therefore the 
 */
-(NSInteger)accountsCountForIsActive:(BOOL)isActive{
    NSInteger iAccounts = 0; //TODO getRealCnt -JN
    for(int i=0;i<MAX_ACCOUNTS;i++){
        if(getAccountByID(i,isActive))iAccounts++;
        else break;
    }
    return iAccounts;
}

- (void *)accountAtIndex:(NSInteger)idx {
    return [self accountAtIndex:idx isActive:YES];
}

-(void *)accountAtIndex:(NSInteger)idx isActive:(BOOL)isActive{
    void *account = getAccountByID((int)idx, isActive);
    return account;
}

//-(NSString *)infoForAccountAtIndex:(NSInteger)idx forKey:(NSString *)aKey{
//    return [self infoForAccountAtIndex:idx isActive:YES forKey:aKey];
//}
//
//-(NSString *)infoForAccountAtIndex:(NSInteger)idx isActive:(BOOL)isActive forKey:(NSString *)aKey{
//    void *account = [self accountAtIndex:idx isActive:isActive];
//    const char *p = sendEngMsg(account, aKey.UTF8String);
//    if(!p)return nil;
//    return [NSString stringWithUTF8String:p];
//}


#pragma mark - Current DOut Methods

-(void *)getCurrentDOut{
    return getCurrentDOut();
}

-(int)setCurrentDOut:(void*)acct{
    return setCurrentDOut(acct);
}

-(NSString *)currentDOutState:(void*)acct {
    if(!acct)acct = [self getCurrentDOut];
    NSString *ret = [self callEng:acct withMsg:@"isON"];
    return ret;
}

- (BOOL)currentDOutIsNULL {
    void *eng = [self getCurrentDOut];
    return (eng==NULL);
}

-(BOOL)isCurrentDOut:(id)acct{
    void *currAccount = [self getCurrentDOut];
    BOOL ret = (currAccount == (__bridge void *)(acct));
    return ret;
}

-(BOOL)accountAtIndexIsCurrentDOut:(NSInteger)idx{
    void *account = [self accountAtIndex:idx isActive:YES];
    void *curAccount = [self getCurrentDOut];    
    return (account==curAccount);
}


#pragma mark - Utilities

- (BOOL)hasNonSilentCircleAccounts{
    
    int n = (int)[self countOfActiveAccounts];
    for (int i=0;i<n;i++){
        void *p = [self accountAtIndex:i];
        if(p && ![[self titleForAccount:p] isEqualToString:@"SilentCircle"])return YES;
    }
    return NO;
}

- (NSString *)titleForAccount:(void *)acct {
    const char *tPtr = getAccountTitle(acct);
    NSString *retStr = [NSString stringWithUTF8String:tPtr];
    return retStr;
}

- (NSString *)numberForAccount:(void *)acct {
    return [self callEng:acct withMsg:@"cfg.nr"];
}

- (NSString *)usernameForAccount:(void *)acct {
    return [self callEng:acct withMsg:@"cfg.un"];
}

-(NSString *)regErrorForAccount:(void *)acct {
    //    const char *pErr = sendEngMsg(acct,"regErr");
    //    NSString *retStr = (pErr==NULL) ? nil : [NSString stringWithUTF8String:pErr];
    //    return retStr;
    return [self callEng:acct withMsg:@"regErr"];
}

- (void *)emptyAccount {
    return getEmptyAccount();
}

// helper
- (NSString *)callEng:(void *)acct withMsg:(NSString *)msg {
    if (NULL == acct || nil == msg || msg.length == 0) return nil;    
    const char *s = sendEngMsg(acct, [msg UTF8String]);
    NSString *retStr = (s==NULL) ? nil : [NSString stringWithUTF8String:s];
    return retStr;
}


- (BOOL)boolFromStrPtr:(const char *)p {
    NSString *str = [NSString stringWithUTF8String:p];
    BOOL ret = ([str isEqualToString:@"yes"] || [str isEqualToString:@"true"]);
    return ret;
}

@end
