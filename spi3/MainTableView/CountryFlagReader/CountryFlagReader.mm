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


#import "CountryFlagReader.h"
#import "SP_FastContactFinder.h"
@implementation CountryFlagReader
{
    NSArray *countryCodeStringsArray;
}

+(CountryFlagReader *)countryFlagReaderInstance
{
    static dispatch_once_t once;
    static CountryFlagReader *countryFlagReaderInstance;
    dispatch_once(&once, ^{
        countryFlagReaderInstance = [[self alloc] init];
        [countryFlagReaderInstance openCountryFile];
    });
    
    return countryFlagReaderInstance;
}
/*
-(id) init
{
    if(self = [super init])
    {
        
        [self openCountryFile];
    }
    return self;
}*/

-(void) openCountryFile
{
    NSString* fileRoot = [[NSBundle mainBundle]
                          pathForResource:@"Country" ofType:@"txt"];
    
    NSString* fileContents = [NSString stringWithContentsOfFile:fileRoot encoding:NSUTF8StringEncoding error:nil];
    
    countryCodeStringsArray = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    // then break down even further
   // NSString* strsInOneLine =
    //[countryCodeStrings objectAtIndex:0];
}

/*
 Reads Country.txt file row by row, looking for country prefix after + sign
 Iterates through all records until finds a record with a country state
 In cases where state doesnt exist, still iterate through entire countrycodeStringsArray
 @param searchText - string to search for
 
 @return dictionary with prefix and fullname as country name keys
 
 */

/*
-(NSDictionary *) getCountryFlagName:(NSString *) searchText
{
    
    if([searchText hasPrefix:@"+"] && searchText.length >= 2)
    {
        searchText = [searchText substringFromIndex:1];
        
        NSString *fullNameString;
        NSString *prefixString;
        for (NSString *countryString in countryCodeStringsArray)
        {
            NSArray *countryStringArray = [countryString componentsSeparatedByString:@":"];
            if(countryStringArray.count > 1)
            {
                if([searchText hasPrefix:countryStringArray[1]])
                {
                    fullNameString = countryStringArray[3];
                    prefixString = countryStringArray[2];
                    
                    if(countryStringArray.count >= 4)
                    {
                        NSString *countryState = countryStringArray[4];
                        if(countryState.length > 0)
                        {
                            fullNameString = [NSString stringWithFormat:@"%@, %@",countryStringArray[4],fullNameString];
                            
                            return @{@"prefix":prefixString,@"fullName":fullNameString};
                        }
                    }
                }
            }
        }
        if(fullNameString && prefixString)
            return @{@"prefix":prefixString,@"fullName":fullNameString};
    }
    return nil;
}*/

-(void) getCountryFlagName:(NSString*) searchText completitionBlock:(void (^)(NSDictionary *countryData)) completition
{
   // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        int findCSC_C_S(const char *nr, char *szCountry, char *szCity, char *szID, int iMaxLen);
        char bufC[64],szCity[64],sz2[64];
        
        
        
        if(findCSC_C_S(searchText.UTF8String, &bufC[0], &szCity[0], &sz2[0],64)>0){
            NSString *cc = [NSString stringWithFormat:@"%s %s",szCity,bufC ];
            
            NSDictionary *dict = @{@"prefix":[NSString stringWithUTF8String:&sz2[0]],@"fullName":cc};
            
            completition(dict);
        }
        
        /*
        if([searchText hasPrefix:@"+"] && searchText.length >= 2)
        {
            NSString *searchTextWithoutPlus;
            searchTextWithoutPlus = [searchText substringFromIndex:1];
            
            NSString *fullNameString;
            NSString *prefixString;
            for (NSString *countryString in countryCodeStringsArray)
            {
                NSArray *countryStringArray = [countryString componentsSeparatedByString:@":"];
                if(countryStringArray.count > 1)
                {
                    
                    
                    if([searchTextWithoutPlus hasPrefix:countryStringArray[1]])
                    {
                        fullNameString = countryStringArray[3];
                        prefixString = countryStringArray[2];
                        
                        if(countryStringArray.count >= 4)
                        {
                            NSString *countryState = countryStringArray[4];
                            if(countryState.length > 0)
                            {
                                fullNameString = [NSString stringWithFormat:@"%@, %@",countryStringArray[4],fullNameString];
                                
                                completition( @{@"prefix":prefixString,@"fullName":fullNameString});
                                return ;
                            }
                        }
                    }
                }
            }
            if(fullNameString && prefixString)
            {
                completition( @{@"prefix":prefixString,@"fullName":fullNameString});
                return;
            }
        }
        completition (nil);
*/
   // });
}
/*
[utilitiesInstance loginWithUserName:@"username" completitionBlock:^(BOOL finished){
    if(finished)
    {
        NSLog(@"i logged in with username");
    } else
        NSLog(@"no username");
    
}];*/

@end
