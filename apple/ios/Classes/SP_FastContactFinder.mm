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

#import <UIKit/UIKit.h>

#import "SP_FastContactFinder.h"

#include <ctype.h>
#include <string.h>
#include "../../../baseclasses/CTListBase.h"

#if __has_feature(objc_arc)
#define ARC
#endif


#define min(_A, _B) ((_A)<(_B) ? (_A):(_B))
unsigned int crc32(const void *ptr, size_t cnt);
int isSPURL(const char *p, int &l);

class CTListItemIndexNR: public CListItem{
   ABRecordRef person;
   char bufNR[64-8];
   int iOutLen;
public:
   int idx;
   static unsigned int getCRC(const char *nr, int iLen, char *out, int *iOutLen){
      if(iLen>=*iOutLen)iLen=*iOutLen;
      
      iLen--;
      
      int iNotDigits=0;
      const char *lp=nr+iLen;
      int o1=0;
      
      while(*lp && iLen>=0){
         while(iLen>=0 && !isalnum(*lp) && *lp!='@' && *lp!='.'){lp--;iLen--;}
         if(iLen<0 || !*lp)break;
         out[o1]=*lp;
         o1++;
         if(!isdigit(*lp))iNotDigits++;
         lp--;iLen--;
      }
      out[o1]=0;
      
      
      *iOutLen=o1;
      
      
      if(iNotDigits || o1<7)return crc32(out,o1);
      
      return crc32(out,min(o1,7));
      
   }
   CTListItemIndexNR(const char *nr, int iLen, ABRecordRef p,  int idx)
   :person(p),idx(idx){
      
      iOutLen=sizeof(bufNR)-1;
      iItemId=(int)getCRC(nr,iLen,&bufNR[0],&iOutLen);
      
    //  printf("[load=%s crc=%x]\n",bufNR,iItemId);
      
   }
   
   ABRecordRef getPerson(){return person;}//
   
   int isItem(void *p, int iSize){
      if(iSize!=sizeof(_SEARCH))return 0;
      _SEARCH *s=(_SEARCH*)p;
      if(s->crc!=iItemId)return 0;
      if(s->nr.iLen==iOutLen){
         return memcmp(s->nr.buf, bufNR, iOutLen)==0;
      }
      if((s->nr.iLen>iOutLen && (s->nr.iLen+1!=iOutLen)) || s->nr.iLen<7 || iOutLen<7)return 0;
      
      for(int i=0;i<s->nr.iLen;i++)
         if(isalpha(s->nr.buf[i]))
            return 0;
      
      return memcmp(s->nr.buf, bufNR, min(iOutLen,min(s->nr.iLen,7)))==0;
   }
   typedef struct{
      unsigned int crc;
      struct{
         char buf[64];
         int iLen;
      }nr;
      
   }_SEARCH;
   
};

void t__ABExternalChangeCallback(ABAddressBookRef addressBook, CFDictionaryRef info, void *context);
NSString* setPersonName(ABRecordRef person);


class CTContactFinder{
   //10, 1024, 1023
   enum{eShift=10,eListCnt=(1<<eShift),eAnd=eListCnt-1};
   
   int iInitOk;
   
   CTList lists[eListCnt];
   
   void loadPerson(int idx, ABRecordRef person, ABPropertyID property){
      
      
      ABMultiValueRef phones = ABRecordCopyValue(person, property);
      
      
      int iPhoneCnt = (int)ABMultiValueGetCount(phones);
      
      for(CFIndex i = 0; i < iPhoneCnt; i++) {
         
         
         CFStringRef m=(CFStringRef)ABMultiValueCopyValueAtIndex(phones, i);
#ifdef ARC
         NSString* mobile=(NSString*)CFBridgingRelease(m);
#else
         NSString* mobile=(NSString*)m;
#endif
         const char *p=[mobile UTF8String];
         int l=(int)strlen(p);//[mobile length];
         
         p+=isSPURL(p,l);
         
         CTListItemIndexNR *n=new CTListItemIndexNR(p,l,person,idx);
         lists[n->iItemId&eAnd].addToRoot(n);
#ifndef ARC
         CFRelease(m);
#endif
         

      }
      CFRelease(phones);
   }
   void rel(){
      if(!iInitOk)return;
      iInitOk=0;
      for(int i=0;i<eListCnt;i++){
         lists[i].removeAll();
      }
#ifndef ARC
      [people release];
#endif
      people = nil;
      //[people release];
      ABAddressBookUnregisterExternalChangeCallback(ab,t__ABExternalChangeCallback, (__bridge void *)(this));
      CFRelease(ab);
      ab=nil;
      
      
   }
   unsigned int setupSearch(CTListItemIndexNR::_SEARCH &s, const char *nr, int iLen){
      
      
      s.nr.iLen=sizeof(s.nr.buf);
      s.crc = CTListItemIndexNR::getCRC(nr,iLen,s.nr.buf,&s.nr.iLen);
     // printf("[search=(%.*s) %x]",iLen,nr,s.crc);
      return s.crc;
   }
   
   ABAddressBookRef ab;
   
   NSArray *people;
public:
   ABAddressBookRef getAB(){return ab;}
   int iHasChanges;
   
   CTContactFinder(){iHasChanges=0;iInitOk=0;ab=nil;people=nil;}
   ~CTContactFinder(){rel();}
   
   void reset(){
      rel();
      load();
   }
   
   int load(ABAddressBookRef abref=NULL){
      if(iInitOk)return 0;
      iInitOk=1;
      
    //  ab = ABAddressBookCreate();
      CFErrorRef error = nil;
      ab = nil;
      ab = abref? abref : ABAddressBookCreateWithOptions(NULL, (CFErrorRef *)&error);
      if (error) { NSLog(@"---%@---", error); }
      
      if(!ab){iInitOk=0;return -1;}
      
      ABAddressBookRegisterExternalChangeCallback(ab,t__ABExternalChangeCallback, (__bridge void *)(this));
      iHasChanges=0;
      
#ifdef ARC
      people = (NSArray *) CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(ab));
#else
      people = (NSArray *) ABAddressBookCopyArrayOfAllPeople(ab);
#endif
     // NSLog(@"[ABAddressBookGetPersonCount=%ld]",ABAddressBookGetPersonCount(ab));
      
      if ( people){
         int c=(int)[people count];
         for (int i=0; i<c; i++ )
         {
            ABRecordRef person = (__bridge ABRecordRef)[people objectAtIndex:i];
            loadPerson(i,person,kABPersonPhoneProperty);
            loadPerson(i,person,kABPersonURLProperty);
            
         }
         
      }
      else iInitOk=0;
      
      return 0;
      
   }
   
   ABRecordRef getPersonByIdx(int i){
      if(!people)return NULL;
      
      int c=(int)[people count];
      if(i>=c)return NULL;
      
      return (__bridge ABRecordRef)[people objectAtIndex:i];
   }
   
   NSString* findPerson(const char *nr, int iLen, int *idx){
      
      if(idx) *idx=-1;
      
      if(iHasChanges)reset();else load();
      int i;
      int iDigits=0;
      
      
      char buf[128];
      if(iLen>127)iLen=127;
      
      int iNewLen=0;
      int iClean=1;
      
      //iDigits+=iClean && !!isdigit(nr[i]);
      for(i=0;i<iLen;i++){
         if(!isascii(nr[i]))continue;//-------------new----
         
         if(nr[i]=='@' || isalpha(nr[i]))iClean=0;
         if(isdigit(nr[i]) || nr[i]=='+' || !iClean){buf[iNewLen]=nr[i];iNewLen++; }
      }
      buf[iNewLen]=0;iLen=iNewLen;nr=&buf[0];
      
      
      unsigned int crc;
      
      CTListItemIndexNR *ret;
      
      CTListItemIndexNR::_SEARCH s;
      
      crc=setupSearch(s,nr,iLen);
      
      ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
      
      if(!ret){
         
         
         for(i=0;i<128;i++){
            
            iDigits+=isdigit(nr[i]);
            
            if(nr[i]=='@' || !nr[i]){
               printf("digits=%d \n",iDigits);
               
               if(iDigits==10){
                  //try to add US country code 1
                  char bufTmp[256];
                  int l = snprintf(bufTmp, sizeof(bufTmp),"1%.*s",iLen,nr);
                  crc=setupSearch(s,&bufTmp[0],l);
                  ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
                  if(ret)break;//found
                  
               }
               
               crc=setupSearch(s,&nr[0],i);
               ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
               if(!ret && iDigits==11){
                  crc=setupSearch(s,&nr[1+(nr[0]=='+')],10);
                  ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
               }
               
               break;
            }
            
         }
      }
      if(!ret && iLen>1 && nr[0]=='+'){
         crc=setupSearch(s,&nr[1],iLen-1);
         ret=(CTListItemIndexNR*)lists[crc&eAnd].findItem(&s,sizeof(s));
      }
      if(!ret)return nil;
      if(idx) *idx=ret->idx;
      return setPersonName(ret->getPerson());
   }
   
   void needsUpdate(){
      iHasChanges++;
   }
};

void t__ABExternalChangeCallback(ABAddressBookRef addressBook, CFDictionaryRef info, void *context){
   CTContactFinder *f=(CTContactFinder*)context;
   if(f)f->needsUpdate();
}

CTContactFinder contactFinder;

@implementation SP_FastContactFinder

+(ABAddressBookRef)getAB{return contactFinder.getAB();}

+(void)needsUpdate{contactFinder.needsUpdate();}

+(void)start{
   

   ABAddressBookRef addressBook;
   if (ABAddressBookGetAuthorizationStatus() != kABAuthorizationStatusAuthorized) {
      CFErrorRef error = nil;
      addressBook = ABAddressBookCreateWithOptions(NULL,&error);
      ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
         // callback can occur in background, address book must be accessed on thread it was created on
         dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
               NSLog(@"AB access error");
            } else if (!granted) {
               NSLog(@"AB access !granted");
            } else {
               // access granted
               //AddressBookUpdated(addressBook, nil, self);
               dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                  contactFinder.load(addressBook);
               });
               NSLog(@"AB access granted");

            }
         });
      });
   } else {
      // iOS 4/5
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         contactFinder.load();
      });
   }
   
   
/*
   CFErrorRef error=NULL;
   ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, (CFErrorRef *)&error);
   if (error) { NSLog(@"---%@---", error); }
   
   NSLog(@"[ABAddressBookGetPersonCount=%d]",ABAddressBookGetPersonCount(ab));
  */

}

+(NSString*) findPerson:(const char *)number iLen:(int)iLen  idx:(int *)idx{
   return contactFinder.findPerson(number, iLen, idx);
}


+(NSString*) findPerson:(NSString *)number  idx:(int *)idx
{
   
   if(!number)return nil;
   const char *p = [number UTF8String];
   return [SP_FastContactFinder findPerson:p  iLen:(int)strlen(p) idx:idx];
}

+(UIImage *)getPersonImage:(int) idx{
   
   if(idx<0)return nil;
   
   UIImage *img = nil;
   NSData *imageData=NULL;
   ABRecordRef person = contactFinder.getPersonByIdx(idx);
   if(person && ABPersonHasImageData(person)){
      
#ifdef ARC
      imageData = CFBridgingRelease(ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail)) ;
#else
      imageData = (NSData *)ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail) ;
#endif
      if(imageData)
      {
         img =  [UIImage imageWithData:imageData] ;
#ifndef ARC
         [imageData release];
#endif
         imageData = nil;

      }
   }
   return img;
   
}

@end

NSString* setPersonName(ABRecordRef person){
   //
   CFStringRef first,last;
   
   first = (CFStringRef)ABRecordCopyValue(person, kABPersonFirstNameProperty);
   last = (CFStringRef)ABRecordCopyValue(person, kABPersonLastNameProperty);
   NSString *f=(__bridge NSString*)first;
   NSString *l=(__bridge NSString*)last;
   //   NSLog(@"name[%@,%@]",f,l);
   //name->setLen(0);
   
   NSString *ret = nil;
   
   if(f && l){
      ret = [NSString stringWithFormat:@"%@ %@", f, l];
      CFRelease(first);
      CFRelease(last);
   }
   else if(f){
      ret = [NSString stringWithString:f];
      CFRelease(first);
   }
   else if(l){
      ret  = [NSString stringWithString:l];
      CFRelease(last);
   }
   else{
      
      CFStringRef cn = (CFStringRef)ABRecordCopyValue(person, kABPersonOrganizationProperty);
      if(cn){
         l=(__bridge NSString*)cn;
         ret  = [NSString stringWithString:l];
         CFRelease(cn);
      }
   }
   
   return ret;
}



int isSPURL(const char *p, int &l){
   
#define SP "silentphone:"
#define SP_LEN (sizeof(SP)-1)
   
   //TODO case insens
   if(strncmp(p,SP,SP_LEN)==0){
      l-=SP_LEN;
      p+=SP_LEN;
      if(l>2 && p[0]=='/' && p[1]=='/'){
         l-=2;
         return SP_LEN+2;
      }
      return SP_LEN;
   }
#undef SP
#undef SP_LEN
   
#define SP "sip:"
#define SP_LEN (sizeof(SP)-1)
   
   //TODO case insens
   if(strncmp(p,SP,SP_LEN)==0){
      l-=SP_LEN;
      p+=SP_LEN;
      if(l>2 && p[0]=='/' && p[1]=='/'){
         l-=2;
         return SP_LEN+2;
      }
      return SP_LEN;
   }
   return 0;
}
