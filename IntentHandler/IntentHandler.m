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
//
//  IntentHandler.m
//  IntentHandler
//
//  Created by Stelios Petrakis on 01/11/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "IntentHandler.h"

@import Contacts;

@interface IntentHandler () <
                                INStartAudioCallIntentHandling
                                ,INStartVideoCallIntentHandling
                                //,INSendMessageIntentHandling
                            >

@end

@implementation IntentHandler

//TODO: Disable SendMessageIntent until we can create a way to send messages using extensions without opening the app

/*
#pragma mark - INSendMessageIntentHandling

- (void)handleSendMessage:(INSendMessageIntent *)intent
               completion:(void (^)(INSendMessageIntentResponse * _Nonnull))completion {
    
    if(!intent.recipients) {
        
        INSendMessageIntentResponse *response = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        
        return;
    }
    
    if([intent.recipients count] == 0) {
        
        INSendMessageIntentResponse *response = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeFailure
                                                                                     userActivity:nil];
        
        completion(response);
        return;
    }
    
    if(![[intent.recipients firstObject] personHandle]) {
        
        INSendMessageIntentResponse *response = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeFailure
                                                                                     userActivity:nil];
        
        completion(response);
        return;
    }
    
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INSendMessageIntent class])];
    
    INSendMessageIntentResponse *response = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeFailureRequiringAppLaunch
                                                                                 userActivity:userActivity];
    
    completion(response);
}

//- (void)confirmSendMessage:(INSendMessageIntent *)intent
//                completion:(void (^)(INSendMessageIntentResponse *response))completion {
//    
//    // TODO: Verify user is authenticated and Silent Phone is ready to send a message.
//    
//    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INSendMessageIntent class])];
//    
//    INSendMessageIntentResponse *response = [[INSendMessageIntentResponse alloc] initWithCode:INSendMessageIntentResponseCodeReady
//                                                                                 userActivity:userActivity];
//
//    completion(response);
//}

- (void)resolveContentForSendMessage:(INSendMessageIntent *)intent
                      withCompletion:(void (^)(INStringResolutionResult * _Nonnull))completion {

    NSString *text = intent.content;
    
    if (text && ![text isEqualToString:@""]) {
        
        completion([INStringResolutionResult successWithResolvedString:text]);
        
    } else {
        
        completion([INStringResolutionResult needsValue]);
    }
}

- (void)resolveRecipientsForSendMessage:(INSendMessageIntent *)intent
                         withCompletion:(void (^)(NSArray<INPersonResolutionResult *> * _Nonnull))completion {
    
    [self resolveContacts:intent.recipients
                allowPSTN:NO
           withCompletion:completion];
}
*/

#pragma mark - INStartVideoCallIntentHandling

- (void)handleStartVideoCall:(INStartVideoCallIntent *)intent
                  completion:(void (^)(INStartVideoCallIntentResponse * _Nonnull))completion {
  
    if(!intent.contacts) {
        
        INStartVideoCallIntentResponse *response = [[INStartVideoCallIntentResponse alloc] initWithCode:INStartVideoCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        
        return;
    }
    
    if([intent.contacts count] == 0) {
        
        INStartVideoCallIntentResponse *response = [[INStartVideoCallIntentResponse alloc] initWithCode:INStartVideoCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        return;
    }
    
    if(![[intent.contacts firstObject] personHandle]) {
        
        INStartVideoCallIntentResponse *response = [[INStartVideoCallIntentResponse alloc] initWithCode:INStartVideoCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        return;
    }
    
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INStartVideoCallIntent class])];
    
    INStartVideoCallIntentResponse *response = [[INStartVideoCallIntentResponse alloc] initWithCode:INStartVideoCallIntentResponseCodeContinueInApp
                                                                                       userActivity:userActivity];
    
    completion(response);
}

//- (void)confirmStartVideoCall:(INStartVideoCallIntent *)intent
//                   completion:(void (^)(INStartVideoCallIntentResponse *response))completion {
// 
//    // TODO: Verify user is authenticated and Silent Phone is ready to start an video call.
//    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INStartVideoCallIntent class])];
//    
//    INStartVideoCallIntentResponse *response = [[INStartVideoCallIntentResponse alloc] initWithCode:INStartVideoCallIntentResponseCodeReady
//                                                                                       userActivity:userActivity];
//
//    completion(response);
//}

- (void)resolveContactsForStartVideoCall:(INStartVideoCallIntent *)intent
                          withCompletion:(void (^)(NSArray<INPersonResolutionResult *> * _Nonnull))completion {
    
    [self resolveContacts:intent.contacts
                allowPSTN:NO
           withCompletion:completion];
}

#pragma mark - INStartAudioCallIntentHandling

- (void)handleStartAudioCall:(INStartAudioCallIntent *)intent
                  completion:(void (^)(INStartAudioCallIntentResponse *response))completion {
    
    if(!intent.contacts) {
        
        INStartAudioCallIntentResponse *response = [[INStartAudioCallIntentResponse alloc] initWithCode:INStartAudioCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        
        return;
    }
    
    if([intent.contacts count] == 0) {
        
        INStartAudioCallIntentResponse *response = [[INStartAudioCallIntentResponse alloc] initWithCode:INStartAudioCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        return;
    }
    
    if(![[intent.contacts firstObject] personHandle]) {
                
        INStartAudioCallIntentResponse *response = [[INStartAudioCallIntentResponse alloc] initWithCode:INStartAudioCallIntentResponseCodeFailure
                                                                                           userActivity:nil];
        
        completion(response);
        return;
    }
    
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INStartAudioCallIntent class])];
    
    INStartAudioCallIntentResponse *response = [[INStartAudioCallIntentResponse alloc] initWithCode:INStartAudioCallIntentResponseCodeContinueInApp
                                                                                       userActivity:userActivity];
    
    completion(response);
}

//- (void)confirmStartAudioCall:(INStartAudioCallIntent *)intent
//                   completion:(void (^)(INStartAudioCallIntentResponse *response))completion {
//    
//    // TODO: Verify user is authenticated and Silent Phone is ready to start an audio call.
//
//    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSStringFromClass([INStartAudioCallIntent class])];
//
//    INStartAudioCallIntentResponse *response = [[INStartAudioCallIntentResponse alloc] initWithCode:INStartAudioCallIntentResponseCodeReady
//                                                                                       userActivity:userActivity];
//
//    completion(response);
//}

- (void)resolveContactsForStartAudioCall:(INStartAudioCallIntent *)intent
                          withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion {
    
    [self resolveContacts:intent.contacts
         allowPSTN:YES
           withCompletion:completion];
}

#pragma mark - Shared methods

- (void)resolveContacts:(NSArray<INPerson *> *)contacts
              allowPSTN:(BOOL)allowPSTN
         withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion {
    
    // If no recipients were provided we'll need to prompt for a value.
    if (contacts.count == 0) {
        
        completion(@[[INPersonResolutionResult needsValue]]);
        return;
    }
    
    NSMutableArray <INPersonResolutionResult *> *resolutionResults = [NSMutableArray new];
    
    // Enumerate the contacts array until you find a valid match
    for (INPerson *person in contacts) {

        // Find a matching Address Book contact
        
        CNContactStore* addressBook = [CNContactStore new];
        NSError *contactError       = nil;
        NSArray <id<CNKeyDescriptor>> *keysToFetch = @[CNContactGivenNameKey,
                                                       CNContactFamilyNameKey,
                                                       CNContactPhoneNumbersKey,
                                                       CNContactUrlAddressesKey,
                                                       CNContactInstantMessageAddressesKey,
                                                       CNContactEmailAddressesKey];
        
        NSArray<CNContact*> *addressBookContacts = nil;
        
        NSPredicate *predicate = [CNContact predicateForContactsMatchingName:person.displayName];
        
        addressBookContacts = [addressBook unifiedContactsMatchingPredicate:predicate
                                                                keysToFetch:keysToFetch
                                                                      error:&contactError];
        
        if(contactError || !addressBookContacts) {
            
            [resolutionResults addObject:[INPersonResolutionResult unsupported]];
            continue;
        }
        
        if(addressBookContacts.count == 0) {
            
            [resolutionResults addObject:[INPersonResolutionResult unsupported]];
            continue;
        }
        
        if(addressBookContacts.count == 1) {

            INPerson *newPerson = [self personForContact:[addressBookContacts firstObject]
                                               allowPSTN:allowPSTN
                                             usingPerson:person];

            if(newPerson)
                [resolutionResults addObject:[INPersonResolutionResult successWithResolvedPerson:newPerson]];
            else
                [resolutionResults addObject:[INPersonResolutionResult unsupported]];
            
            continue;
        }
        
        INPerson *scPerson = nil;
        INPerson *telPerson = nil;
        
        // Enumerate the Address Book array until you find a valid match
        for (CNContact *contact in addressBookContacts) {
            
            INPerson *newPerson = [self personForContact:contact
                                               allowPSTN:allowPSTN
                                             usingPerson:person];
            
            if(!newPerson)
                continue;
            
            if(newPerson.personHandle.type == INPersonHandleTypeUnknown || newPerson.personHandle.type == INPersonHandleTypeEmailAddress)
                scPerson = newPerson;
            else
                telPerson = newPerson;
        }
        
        if(scPerson)
            [resolutionResults addObject:[INPersonResolutionResult successWithResolvedPerson:scPerson]];
        else if(telPerson)
            [resolutionResults addObject:[INPersonResolutionResult successWithResolvedPerson:telPerson]];
        else
            [resolutionResults addObject:[INPersonResolutionResult unsupported]];
    }
    
    completion(resolutionResults);
}

- (INPersonHandle *)handleForValue:(NSString *)valueString type:(INPersonHandleType)type {

    if(!valueString)
        return nil;
    
    INPersonHandle *handle = nil;
    
    if([valueString hasPrefix:@"sip:"] || [valueString hasPrefix:@"silentphone:"] || [valueString hasSuffix:@"@sip.silentcircle.net"]) {
        
        handle = [[INPersonHandle alloc] initWithValue:valueString
                                                  type:type];
    }
    
    return handle;
}

// Try to find a Silent Circle username (sip:xxxx silentphone:xxxx xxx@sip.silentcircle.net)
// otherwise use the first phone number
- (INPerson *)personForContact:(CNContact *)contact allowPSTN:(BOOL)allowPSTN usingPerson:(INPerson *)fallbackPerson {
    
    if(!contact)
        return nil;
    
    INPersonHandle *personHandle = nil;
    
    // Try to find a Silent Circle username (sip:xxxx silentphone:xxxx xxx@sip.silentcircle.net)
    // otherwise use the first phone number
    
    for (CNLabeledValue *emailAddress in contact.emailAddresses) {
        
        INPersonHandle *handle = [self handleForValue:(NSString *)emailAddress.value
                                                 type:INPersonHandleTypeEmailAddress];
        
        if(handle) {
            
            personHandle = handle;
            break;
        }
    }
    
    if(!personHandle) {

        for (CNLabeledValue *urlAddress in contact.urlAddresses) {

            INPersonHandle *handle = [self handleForValue:(NSString *)urlAddress.value
                                                     type:INPersonHandleTypeUnknown];
            
            if(handle) {
                
                personHandle = handle;
                break;
            }
        }
    }
    
    if(!personHandle) {
        
        for (CNLabeledValue *instantMessageAddress in contact.instantMessageAddresses) {
            
            CNInstantMessageAddress *address = (CNInstantMessageAddress *)instantMessageAddress.value;
            
            if(![address.service isEqualToString:@"Silent Phone"] && ![address.service isEqualToString:@"Silent Circle"])
                continue;
            
            INPersonHandle *handle = [self handleForValue:address.username
                                                     type:INPersonHandleTypeUnknown];
            
            if(handle) {
                
                personHandle = handle;
                break;
            }
        }
    }
    
    // If we can't find a username, pick up a phone number
    if(!personHandle && allowPSTN && contact.phoneNumbers.count > 0) {
        
        CNLabeledValue *phoneNumber = [contact.phoneNumbers firstObject];
        
        CNPhoneNumber *contactPhoneNumber = (CNPhoneNumber *)phoneNumber.value;
        
        personHandle = [[INPersonHandle alloc] initWithValue:contactPhoneNumber.stringValue
                                                        type:INPersonHandleTypePhoneNumber];
    }
    
    if(!personHandle)
        return nil;
    
    INPerson *person = [[INPerson alloc] initWithPersonHandle:personHandle
                                               nameComponents:fallbackPerson.nameComponents
                                                  displayName:fallbackPerson.displayName
                                                        image:fallbackPerson.image
                                            contactIdentifier:contact.identifier
                                             customIdentifier:fallbackPerson.customIdentifier
                                                      aliases:fallbackPerson.aliases
                                               suggestionType:fallbackPerson.suggestionType];

    return person;
}

@end
