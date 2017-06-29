/*
Created by Janis Narbuts
Copyright (C) 2004-2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2017, Silent Circle, LLC.  All rights reserved.

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
//  Favorites.m
//  VoipPhone
//
//  Created by Janis Narbuts on 6.5.2012.
//  Copyright (c) 2012 Tivi LTD, www.tiviphone.com. All rights reserved.
//
#import <UIKit/UIKit.h>
#define _T_WO_GUI
#import "CTListBase.h"
#import "CTEditBase.h"
#import "CTRecentsItem.h"

const char* sendEngMsg(void *pEng, const char *p);
int fixNR(const char *in, char *out, int iLenMax);

NSString *toNSFromTB(CTStrBase *b);
NSString *toNSFromTBN(CTStrBase *b, int N);
NSString *translateServ(CTEditBase *b);
NSString *checkNrPatterns(NSString *ns);

NSString *checkNrPatterns(NSString *ns) {
    
    char buf[64];
    
    if(fixNR(ns.UTF8String,&buf[0],63))
        return [NSString stringWithUTF8String:&buf[0]];
    
    return ns;
}

NSString *translateServ(CTEditBase *b) {
    
    char bufTmp[128];
    bufTmp[0]='.';
    bufTmp[1]='t';
    bufTmp[2]=' ';
    bufTmp[3]=0;
    
    getText(&bufTmp[3],125,b);
    
    const char *p=sendEngMsg(NULL,&bufTmp[0]);
    
    if(p && p[0])
        return [NSString stringWithUTF8String:p];
    
    return toNSFromTB(b);
}

static int iHasMods = 0;

int removeFromFavorites(CTRecentsItem *i) {
    
    if(!i)
        return 0;
    
    CTRecentsList *fl = CTRecentsList::sharedFavorites();
    
    fl->load();
    
    if(!fl->hasRecord(i))
        return 0;
    
    fl->removeRecord(i);
    
    iHasMods = 1;
    
    return 0;
}

int addToFavorites(CTRecentsItem *i, void *fav, int iFind) {
    
    if(!i)
        return 0;
    
    CTRecentsList *fl = CTRecentsList::sharedFavorites();
    
    fl->load();
    
    if(fl->hasRecord(i))
        return 1;
    
    if(iFind)
        return 0;
    
    CTRecentsItem *n=new CTRecentsItem();
    
    if(!n)
        return 0;
    
    n->name.setText(i->name);
    n->peerAddr.setText(i->peerAddr);
    n->myAddr.setText(i->myAddr);
    n->lbServ.setText(i->lbServ);
    
    fl->getList()->addToTail(n);
    fl->activateAll();
    fl->save();
    
    iHasMods = 1;
    
    return 1;
}