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
#ifndef _CT_INDEX_LIST_H
#define _CT_INDEX_LIST_H

#include "CTListBase.h"

template<int T_shifter> class CTIndexList{
public:
   enum{eLists = 1<<T_shifter, eAnd = eLists - 1};
private:
   CTList lists[eLists];
public:
   
   CTIndexList(){crcFnc=NULL;}
   
   unsigned int (*crcFnc)(const void *p, int iLen);
   
   void removeAll(){
      for (int i = 0; i<eLists; i++){
         lists[i].removeAll();
      }
   }
   
   void add(CListItem *item){
      if(!item)return;
      CTList *l = &lists[item->uiCrc & eAnd ];
      l->addToRoot(item);
   }
   
   void remove(CListItem *item, int iDel = 1){
      if(!item)return;
      CTList *l = &lists[item->uiCrc & eAnd ];
      l->remove(item, iDel);
   }
   
   CListItem *findByKey(const char *key, int iKeyLen=0 ){
      
      if(!key)return NULL;
      
      if(!iKeyLen)iKeyLen = (int)strlen(key);
      
      unsigned int crc = getCRC(key, iKeyLen);

      CTList *l = &lists[crc & eAnd];
      return (CListItem *)l->findItem(crc, key, iKeyLen);
   }
   
   void goThru(int (*fnc)(const void *ret, CListItem *), const void *ret){
      for (int i = 0; i<eLists; i++){
         CListItem *p = lists[i].getNext(NULL,1);
         while(p){
            if(fnc(ret, p)<0)break;
            p = lists[i].getNext(p,1);
         }
      }
   }

   unsigned int getCRC(const char *key, int iKeyLen){
      if(crcFnc)return crcFnc(key, iKeyLen);
      
      unsigned int crc32(const void *ptr, size_t cnt);
      return crc32(key, iKeyLen);
   }
   
};
#endif
