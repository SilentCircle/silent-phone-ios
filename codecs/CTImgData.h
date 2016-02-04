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
#ifndef _C_T_IMG_DATA
#define _C_T_IMG_DATA

#ifndef _C_T_BASE_H
#include "../baseclasses/CTBase.h"
#endif

class CTImgData: public CTBmpBase{
  unsigned char *buf;
  unsigned char *bufPic;
  int x,y;
  int iMustDelete;
  int iInitSize;
public:  
   unsigned char *getBuf(){return buf;}
   CTImgData(){iInitSize=x=y=0;iMustDelete=0;bufPic=buf=NULL;}
   virtual ~CTImgData(){if(iMustDelete)delete bufPic;buf=bufPic=NULL;x=0;y=0;}
   void copy(CTImgData *img){
      int stride=x*3;
      int size=x*y*3;
      memcpy(buf,img->buf,size);
      
      memcpy(buf-stride,img->buf,stride);
      memcpy(buf+size,img->buf+size-stride,stride);
   }
   unsigned char * setNewBuf(CTImgData *img)
   {
      unsigned char *pOld=buf;
      img->getXY(x,y);
      buf=img->getBuf();
      if(buf)
         bufPic=img->bufPic;//buf-(2*x+2*y)*3;
      else 
         bufPic=NULL;

      return pOld;
   }
   static void swap(CTImgData *p1,CTImgData *p2)
   {
      CTImgData tmp;
      tmp.setNewBuf(p1);
      p1->setNewBuf(p2);
      p2->setNewBuf(&tmp);
   }
   void getXY(int &w ,int &h){w=x;h=y;}
   inline void setScanLine(int iLine, unsigned char *p, int iLen, int iBits)
   {
      return setScanLine(iLine,0,p,iLen,iBits);
   }
   inline void setScanLine(int iLine, int iXOff, unsigned char *p, int iLen, int iBits)
   {
      if(iLine>=y || iLine<0 || !buf)return;
      int bpp=24;
      unsigned char *c=buf+(x*bpp/8*(iLine)+iXOff*bpp/8);
      memcpy(c,p,iLen);
   }
   virtual void setOutputPictureSize(int cx, int cy)
   {
      if(cx!=x  || cy!=y)
      {
         if(bufPic)delete bufPic;
         buf=bufPic=NULL;
         iMustDelete=0;
         x=cx;
         y=cy;
         if(cx && cy)
         {
           iMustDelete=1;
           iInitSize=(x+4)*(y+30)*3+4095;
           //iInitSize=(iInitSize+4095)&(~4095);
           bufPic=new unsigned char[iInitSize];
           buf=bufPic+(x*15)*3+32;//(x+3)*(y+2)*3+32;
           buf=(unsigned char*)(((size_t) buf+15)&(~15));
         }
      }
   }
   virtual void startDraw(){}
   virtual void endDraw(){}
   virtual int rawJpgData(unsigned char *p, int iLen){return -1;}//ret 0 if use it
};
#endif
