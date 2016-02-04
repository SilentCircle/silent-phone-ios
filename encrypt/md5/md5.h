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

/* POINTER defines a generic pointer type */
#ifndef _T_MD5_H_
#define _T_MD5_H_
typedef unsigned char *POINTER;
typedef unsigned short int UINT2;
typedef unsigned int UINT4;

/* MD5 context. */
typedef struct {
  UINT4 state[4];                                   /* state (ABCD) */
  UINT4 count[2];        /* number of bits, modulo 2^64 (lsb first) */
  unsigned char buffer[64];                         /* input buffer */
} MD5_CTX;

void MD5Init (MD5_CTX *);
void MD5Update (MD5_CTX *, unsigned char *, unsigned int);
void MD5Final (unsigned char [16], MD5_CTX *);
void md5_calc(unsigned char *output, unsigned char *input, unsigned int inlen);
//int  getHash(unsigned char *strHash, const char *strzNonce, const char *strzPwd);
int  getHash16(unsigned char *strHash16, const char *strzNonce, const char *strzPwd);
int  getHash32(unsigned char *strHash32, const char *strzNonce, const char *strzPwd);

//if you ask why -- read (RFC 3621, 2617, 3550) 
class CTMd5{
public:
   CTMd5():iFinal(0)
   {
      MD5Init(&ctx);
   }
   ~CTMd5(){}
   inline void update(const void *p, unsigned int uiLen){return update((unsigned char *)p, uiLen);}
   template <class T>void update(T t){update(&t, sizeof(T));}
   void update(unsigned char *p, unsigned int uiLen)
   {
      if(!uiLen || !p)return;
      if(iFinal)
      {
         iFinal=0;
         MD5Init(&ctx);
      }
      MD5Update(&ctx,p,uiLen);
   }
   void final(unsigned char buf[16])
   {
      MD5Final (buf, &ctx);
      iFinal=1;
   }
   
   unsigned int final()
   {
      int i;
      unsigned int r;
      iFinal=1;
      unsigned int buf[8];//we need only 128bits

      MD5Final ((unsigned char *)&buf[0], &ctx);
      
      r = buf[0];
      
      for(i=1;i<4;i++)
      {
         r^=buf[i];
      }
      
      return r;
   }
   
   const static unsigned char PADDING[64];
private:
   MD5_CTX ctx;
   int iFinal;
};
#endif //_T_MD5_H_
