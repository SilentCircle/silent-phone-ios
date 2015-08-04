/*
Copyright (C) 2013, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2013-2015, Silent Circle, LLC.  All rights reserved.

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

#import "AppDelegate.h"

#include "../../../../../tiviandroid/engcb.h"

int _fnc_cb_ph(void *ret, void *ph, int iCallID, int msgid, const char *psz, int iSZLen){
   printf("========");
   if(psz){
      if(!iSZLen)iSZLen=strlen(psz);
      printf("[%.*s] ", iSZLen, psz);
   }
   printf("msg=%d cid=%d--------------------<>\n", msgid, iCallID);
 
   if(msgid==CT_cb_msg::eIncomCall){
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         sleep(2);
         doCmd("*a", iCallID);//answer call
      });
      
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         sleep(10);
         char b[64];
         snprintf(b,sizeof(b),"*e%d",iCallID);
         doCmd(b);//end call
      });
   }

   return 0;
}

void setFSPath(char *p);

int isTmpWorkingInBackGround(){return 1;}


void _prov_cb(void *p, int ok, const char *pMsg){
   printf("ok=%d msg=%s\n", ok, pMsg);
}


int main(int argc, char * argv[])
{
   
   setFSPath(argv[0]);

   if(!isProvisioned(0)){
  //  checkProv("QJMBWHJH", _prov_cb, NULL);//will wait
   }
   z_main_init();
   

   setPhoneCB(_fnc_cb_ph, 0);
   doCmd(":reg");
   
   doCmd(":c 22146864");
   
   @autoreleasepool {
       return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
   }
}


void tmp_log(const char *p){
   NSLog(@"%s", p);
}


void tivi_log1(const char *p, int val){
   NSLog(@"%s=%d\n", p, val);
}






float cpu_usage(){return 0.1;}
/*
#if 1

#include "../../../../../video/CTVideoOut_Quartz.h"
#include "../../../../../video/CTVideoInIOS.h"

void CTVideoOut::setQWview(void *p){}
int CTVideoOut::start(){return -1;};//{iStarted=1;uiPosTs=0;return 0;}
void CTVideoOut::stop(){}
void CTVideoOut::startDraw(){}
void CTVideoOut::endDraw(){}
void CTVideoOut::setOutputPictureSize(int cx, int cy){}
void CTVideoOut::setScanLine(int iLine, int iXOff, unsigned char *p, int iLen, int iBits){}
int CTVideoOut::getImgParams(int &iYuv, int &iBpp, int &stride, int &iIsBRG, void **p){return -1;}
int CTVideoOut::drawFrame(){return 0;}


unsigned int CTVideoInIOS::onNewVideoData(int *d, unsigned char *yuv, int nw, int nh, int iRotDeg){return 0;}
void CTVideoInIOS::sendBuf(unsigned int uiPos){}
CTVideoInIOS::~CTVideoInIOS(){}
int CTVideoInIOS::start(void *pData){return 0;}
void CTVideoInIOS::stop(void *pData){}
int CTVideoInIOS::init(void *hParent){return 0;}
void CTVideoInIOS::setXY(int x, int y){}//TODO user wants screen x by y
void CTVideoInIOS::setXY_priv(int x, int y, int iRot){}

#endif
*/

