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
#import "DirectorySearcher.h"
#import "UserContact.h"
#import "Utilities.h"

@implementation DirectorySearcher
{
    NSMutableArray *userContactArray;
    
    NSOperationQueue *contactSearchQueue;
    
}
-(id) init
{
    if(self = [super init])
    {
        contactSearchQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}


-(void)searchForUsersWithTextFieldText:(NSString *)textFieldText
{
    // Cancel previous selectors and perform new search
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if(textFieldText.length <= 1)
    {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        return;
    }
    [self performSelector:@selector(searchOperation:) withObject:textFieldText afterDelay:1.0];
}

/**
 * Use NSOperation for contact search
 * stop search whenever new search is initiated
 * if allocating contacts takes longer than wait time for new search and there is new search incoming, stop previous work
 **/
-(void) searchOperation:(NSString *)textFieldText
{
    NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
    
    [blockOperation addExecutionBlock:^{
        
        NSString * url = [ NSString stringWithFormat:@"/v1/people/?terms=%@&api_key=%@&start=0&max=20",textFieldText,[[Utilities utilitiesInstance] getAPIKey]];
        NSString *returnString = [[Utilities utilitiesInstance] getHttpWithUrl:url method:@"GET" requestData:@""];
        NSData *data = [returnString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *resultJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:kNilOptions
                                                                     error:nil];
        if(!userContactArray)
        {
            userContactArray = [[NSMutableArray alloc] init];
        }
        else
        {
            [userContactArray removeAllObjects];
        }
        
        if([[resultJSON objectForKey:@"result"] isEqualToString:@"success"])
        {
            NSArray *people = [resultJSON objectForKey:@"people"];
            for (NSDictionary *userData in people) {
                if([blockOperation isCancelled]) return ;
                NSArray *phoneNumbers = [userData objectForKey:@"numbers"];
                
                // if there is more than 1 phone number, add new user with each number
                if(phoneNumbers.count > 0)
                {
                    for (NSString *number in [userData objectForKey:@"numbers"]) {
                        if([blockOperation isCancelled]) return ;
                        UserContact *newContact = [[UserContact alloc] init];
                        newContact.contactFullName = [userData objectForKey:@"full_name"];
                        newContact.contactUserName = [userData objectForKey:@"username"];
                        newContact.contactPhone = number;
                        [userContactArray addObject:newContact];
                    }
                }
                UserContact *newContact = [[UserContact alloc] init];
                newContact.contactFullName = [userData objectForKey:@"full_name"];
                newContact.contactUserName = [userData objectForKey:@"username"];
                
                // if phone numbers doesnt exist, show username instead
                newContact.contactPhone = newContact.contactUserName;
                [userContactArray addObject:newContact];
                
            }
        }
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if(userContactArray.count > 0)
        {
            if([blockOperation isCancelled]) return ;
            
            // send found items to delegate
            if(self.delegate)
                [[self delegate] addItemsFromNetworkDictionary:userContactArray];
        }
    }];
    
    // cancel previous operations, add this operation
    [contactSearchQueue cancelAllOperations];
    [contactSearchQueue addOperation:blockOperation];
}

-(void) dismissAllOperations
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    self.delegate = nil;
    [contactSearchQueue cancelAllOperations];
}
@end
