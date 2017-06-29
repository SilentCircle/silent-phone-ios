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
#import "SCSPhoneHelper.h"
#import "CTNumberHelper.h"
#import "SCPCallbackInterface.h"

int* findIntByServKey(void *pEng, const char *key);
void *findGlobalCfgKey(const char *key);
int canModifyNumber(void);

@implementation SCSPhoneHelper {
    
    NSArray *countryCodeStringsArray;
    CTNumberHelperBase *ctNumberHelperBase;
}

+(SCSPhoneHelper *)sharedPhoneHelper
{
    static dispatch_once_t once;
    static SCSPhoneHelper *sharedPhoneHelper;
    dispatch_once(&once, ^{
        sharedPhoneHelper = [[self alloc] init];
        sharedPhoneHelper->ctNumberHelperBase = g_getDialerHelper();
        
    });
    
    return sharedPhoneHelper;
}

-(void) openCountryFile
{
    NSString* fileRoot = [[NSBundle mainBundle]
                          pathForResource:@"Country" ofType:@"txt"];
    
    NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:nil];
    
    countryCodeStringsArray = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

-(void) getCountryFlagName:(NSString*) searchText completitionBlock:(void (^)(NSDictionary *countryData)) completition
{
    int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
    char bufC[64],szCity[64],sz2[64];
    
    if(findCSC_C_S(searchText.UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
        
        NSString *cc = [NSString stringWithFormat:@"%s %s",szCity,bufC ];
        NSDictionary *dict = @{@"prefix":[NSString stringWithUTF8String:&sz2[0]],@"fullName":cc};
        
        completition(dict);
        
    } else
        completition(nil);
}

-(int) canModifyNumber:(void*)eng
{
    if(!canModifyNumber())
        return 0;
    
    if(!eng)
        return 0;
    
    static int *iDisableDialingHelper = findIntByServKey(eng, "iDisableDialingHelper");

    return iDisableDialingHelper? !(*iDisableDialingHelper) : 0;
}

/*
 @param ns - not modified string
 @param reset - should reset the number if prefix is found
 @param curDO - current dialout
 
 @return ns modified string
 */
-(NSString*) getModifiedNumber:(NSString *)ns reset:(int)reset eng:(void*)curDO
{
    int iCanModifyNumber = [self canModifyNumber:curDO];
    
    if(iCanModifyNumber) {
        
        if(ns.length<1 || reset)
            ctNumberHelperBase->clear();
        
        static const char *r = (const char *)findGlobalCfgKey("szDialingPrefCountry");

        ctNumberHelperBase->setID(r);
        
        ns = [NSString stringWithUTF8String:ctNumberHelperBase->tryUpdate(ns.UTF8String)];
        ns = [NSString stringWithUTF8String:ctNumberHelperBase->tryRemoveNDD(ns.UTF8String)];
    }
    
    return ns;
}

- (NSString *)phoneNumberWithDialAssist:(NSString *)phoneNumber {
    
    phoneNumber = [[SCSPhoneHelper sharedPhoneHelper] getModifiedNumber:phoneNumber
                                                                  reset:1
                                                                    eng:[Switchboard getCurrentDOut]];
    
    // Pretty heuristic hack here but we need to fix the missing + prefixes
    // in user's contacts before storing them in cache or sending them to server (ref: issue #63)
    // Note: https://github.com/iziz/libPhoneNumber-iOS would be ideal for those kind of stuff
    if([phoneNumber length] > 10 && ![phoneNumber hasPrefix:@"+"] && ![phoneNumber hasPrefix:@"00"])
        phoneNumber = [NSString stringWithFormat:@"+%@", phoneNumber];
    
    return phoneNumber;
}

@end
