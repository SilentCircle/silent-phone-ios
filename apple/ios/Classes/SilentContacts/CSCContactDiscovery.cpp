/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include "../baseclasses/CTIndexList.h"
#include "axolotl/../util/cJSON.h"
#include "CSCContactDiscoveryBase.h"

int t_snprintf(char *buf, int iMaxSize, const char *format, ...);

class CTListItemAlias: public CListItem{
public:
   enum{eHashHexSize=64,eHashHexSizeToServer=5, eHashHexSizeCrc=16};
   
   CTListItemAlias(const char *alias):CListItem(){
      setAlias(alias);
   }
   void setAlias(const char *alias){

      iIsMatching=0;
      iSentToServer=0;
      if(strncmp(alias, "sip:",4)==0)alias += 4;
      
      for(iLen=0;;alias++){
         if(alias[0]==0 || alias[0]=='@')break;
         if(isalnum(alias[0]) || (iLen==0 && alias[0]=='+')){
            a[iLen] = alias[0];
            iLen++;
            if(iLen + 1 >= sizeof(a))break;
         }
      }

      a[iLen] = 0;
      void sha256(unsigned char *data,
                  unsigned int data_length,
                  unsigned char *digest);
      
      void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
      
      unsigned char hashbin[eHashHexSize/2+1];
      
      sha256((unsigned char *)&a[0], iLen, hashbin);
      
      bin2Hex(hashbin,hashhex,eHashHexSize/2);
      
      uiCrc = getCRCFnc(hashhex, eHashHexSizeCrc);
      
   }
   
   virtual int isItem(void *p, int iSize){
      if(iSize>eHashHexSize)return 0;
      
      return memcmp(hashhex,(char*)p, iSize)==0;
   }
   
   static unsigned int getCRCFnc(const void *key, int iKeyLen){
      
      unsigned int crc32(const void *ptr, size_t cnt);
      return crc32(key, eHashHexSizeCrc);
   }
   
   char hashhex[eHashHexSize+4];
   char a[128];
   int iLen;
   
   int iIsMatching;
   int iSentToServer;
};

class CSCContectDiscovery: public CSCContactDiscoveryBase{
   CTIndexList<12> list;
   int iItems;
   int iNewItems;
   int iState;
   char *jsonBuf;
   int iJsonBufLen;
public:
   enum{eDirty, eDiscovering, ePostOk};

   CSCContectDiscovery():CSCContactDiscoveryBase(){
      jsonBuf = NULL;
      reset();

   }
   ~CSCContectDiscovery(){
      reset();
   }
   
   int isMatching(const char *alias, int canCheckOnServer){
      
      
      CTListItemAlias i(alias);
      
      CTListItemAlias *ret = (CTListItemAlias*)list.findByKey(i.hashhex, i.eHashHexSize);
      if(ret && ret->iSentToServer){
         return ret ? ret->iIsMatching : 0;
      }
      
      if(iState != ePostOk){
         puts("WARN: Call the doJob() first");
         if(!canCheckOnServer)return -1;
         void uSleep(int usec );
         while(iState == eDiscovering)uSleep(100);
         if(iState != ePostOk){
            int r = post();
            if(r<0)return -1;
         }
      }
      
      ret = (CTListItemAlias*)list.findByKey(i.hashhex, i.eHashHexSize);
      
      return ret ? ret->iIsMatching : 0;
   }
   int cnt(){return iItems;}
   
   void reset(){
      if(jsonBuf){delete jsonBuf;jsonBuf=NULL;}
      iJsonBufLen = 0;
      list.removeAll();
      iItems = 0; iState = eDirty;
      list.crcFnc = &CTListItemAlias::getCRCFnc;
   }
   
   int doJob(){
      
      int ret = post();
      return 0;
   }
   void terminateJob(){iState=eDirty;}
   
   void addNumber(const char *alias){
      CTListItemAlias *i = new  CTListItemAlias(alias);
      
      //do not let to add existing number
      if(list.findByKey(i->hashhex, i->eHashHexSize)){delete i; return;}
      
      list.add(i);
      
 //     printf("send=%s,crc=%08x\n",i->a, i->uiCrc);
      iItems++;
      iNewItems++;
      //createJson
      iState = eDirty;
   }

private:
   int post(){
      if(!iNewItems)return 0;
      
      iState = eDiscovering;
      createJson();

      //check responce
      char* t_post_json(const char *url, char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent) ;
 
      const char* getCurrentProvSrv();
      const char *web = getCurrentProvSrv();
      char url[256];
      t_snprintf(url, sizeof(url), "%s/v1/contacts/validate/", web);
      
      int iMaxBufRespSize = (CTListItemAlias::eHashHexSize * 2 +4)*iJsonBufLen / CTListItemAlias::eHashHexSizeToServer+1024;
      char *bufResp = new char [iMaxBufRespSize+8];
      int jsonLen = 0;
      
      char *rec = t_post_json(url, bufResp, iMaxBufRespSize, jsonLen, jsonBuf);
      if(rec){
         puts(rec);
      }
      
      int r = setMatching(rec, jsonLen);
      delete bufResp;
      
      iState = ePostOk;
      iNewItems = 0;
      return 0;
   }
   static int sJsonCreateCB(const void *pThis, CListItem*i){
      return((CSCContectDiscovery*)pThis)->jsonCreateCB(i);
   }
   
   int jsonCreateCB(CListItem *i){
      CTListItemAlias *ia = (CTListItemAlias*)i;
      if(ia->iSentToServer)return 0;
      ia->iSentToServer = 2;
      //if too many items in buf then brake, and do it again
      iJsonBufLen += sprintf(jsonBuf + iJsonBufLen, "\"%.*s\",", ia->eHashHexSizeToServer, ia->hashhex);
      return 0;
   }
   
   void createJson(){
      
      if(jsonBuf){delete jsonBuf;jsonBuf=NULL;}
      iJsonBufLen = 0;
      
      int bufSize = iNewItems * (CTListItemAlias::eHashHexSizeToServer + 2 + 1) + 60;
      jsonBuf = new char [bufSize];
      
      iJsonBufLen += sprintf(jsonBuf, "{\"contacts\":[");
      
      list.goThru(&sJsonCreateCB, this);
      
      iJsonBufLen--;//remove last ','
      iJsonBufLen += sprintf(jsonBuf+iJsonBufLen, "]}");
      puts(jsonBuf);
      
   }
   
   
   int setMatching(char *jsonBuf, int jsonLen){
      
      if(jsonLen<10)return -1;
      jsonBuf[jsonLen] = 0;
      
      cJSON* root = cJSON_Parse(jsonBuf);
      if(!root)return -1;
      
      cJSON *c = cJSON_GetObjectItem(root,"contacts");
      if(c && c->type == cJSON_Array){
         
         c = c->child;

         while(c && c->type == cJSON_String){
            
            CTListItemAlias *ret = (CTListItemAlias*)list.findByKey(c->valuestring, strlen(c->valuestring));
            if(ret){
               // if(!ret->iIsMatching)updateLocalDB();
               ret->iIsMatching = 1;
            }
            //printf("%d,ret=%s %d\n",i, c->valuestring,c->type);
            c=c->next;
            
         }
      }
      
      //curl -H "Content-Type: application/json" -X POST -d '{"contacts":["5ed6727f39","f8cb83e1c2","f8e404b342","54acc14631","d22bbb4f8f", "f90d743e1c","fcd1a800de","c370b498f0","1fa5f837c4","81dee91b4e","b0bc34cfb3",  "88035bdb3f","e72eecf434","fc4440358e","1f74e79592","9a108a3675"]}' https://sccps.silentcircle.com/v1/contacts/validate/
      cJSON_Delete(root);
      
      /*
      extern int	  cJSON_GetArraySize(cJSON *array);
      extern cJSON *cJSON_GetArrayItem(cJSON *array,int item);
      extern cJSON *cJSON_GetObjectItem(cJSON *object,const char *string);
       */
      //saveResultsToDisk(); or markthecontact()
      return 0;
      
   }
   
};

//CSCContectDiscovery ll();

CSCContactDiscoveryBase * g_CSCContactDiscoveryObject(){
   static CSCContactDiscoveryBase *c = new CSCContectDiscovery();
   return c;
}
