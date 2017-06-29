/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
//  StoreManager.h
//  SilentText
//
//  Created by Ethan Arutunian on 5/27/14
//  Copyright (c) 2014 Silent Circle, LLC. All rights reserved.
//

 
#import "StoreManager.h"
#import "EmbeddedIAPProduct.h"
#import "SPUser.h"
#import "UserService.h"
#import "AZBase64Transcoder.h"
#import "NSStringExtras.h"
#import "Reachability.h"
#import "SCPCallbackInterface.h"

NSString *const kStoreManager_ProductsLoadedNotification        =  @"kStoreManager_ProductsLoadedNotification";
NSString *const kStoreManager_TransactionCompleteNotification    = @"kStoreManager_TransactionCompleteNotification";


@interface StoreObserver : NSObject <SKPaymentTransactionObserver>
- (void) completeTransaction: (SKPaymentTransaction *)transaction;
- (void) failedTransaction: (SKPaymentTransaction *)transaction;
- (void) restoreTransaction: (SKPaymentTransaction *)transaction;
@end


@implementation StoreObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
			case SKPaymentTransactionStatePurchasing:
				NSLog(@"Adding payment to purchasing queue.");
				break;
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
			{
                [self failedTransaction:transaction];
                break;
			}
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
}

- (void) completeTransaction: (SKPaymentTransaction *)paymentTransaction
{
    // Once you’ve provided the product, your application must call finishTransaction: to complete the operation.
	// When you call finishTransaction:, the transaction is removed from the queue.
	// Your application must ensure that content is provided (or that you’ve recorded the details of the transaction) before calling finishTransaction:
	// send off to SC server
    
    NSString *hashedUserName = paymentTransaction.payment.applicationUsername;
	NSString *userID = (hashedUserName) ? [[StoreManager sharedInstance] hashedObjectForKey:hashedUserName] : nil;
	if (!userID) {
		// if the user doesn't exist, just remove the payment, something went really wrong.
		[[SKPaymentQueue defaultQueue] finishTransaction: paymentTransaction];
		return;
	}

	// payment complete, Tell Silent Circle you paid for it.
	NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
	NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
	
    NSString *endpoint = [NSString stringWithFormat:SCPNetworkManagerEndpointV1UserPurchaseAppStore, userID];
    NSDictionary *arguments = @{ @"receipt": base64EncodeData(receipt) };
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodPOST
                                           arguments:arguments
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              
                                              SPUser *user = nil;
                                              
                                              if(!error)
                                                  user = [[UserService sharedService] updateCurrentUserWithDictionary:(NSDictionary *)responseObject
                                                                                                               userID:userID];
                                              
                                              NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{
                                                                                                                          @"paymentTransaction":  paymentTransaction,
                                                                                                                          @"userId":              hashedUserName
                                                                                                                          }];
                                              if(error)
                                                  [dict setObject:error
                                                           forKey:@"error"];
                                              
                                              if (user)
                                                  [dict setObject:user forKey:@"user"];
                                              
                                              // remove the transaction or it will keep on showing up forever
                                              [[SKPaymentQueue defaultQueue] finishTransaction: paymentTransaction];
                                              
                                              [[NSNotificationCenter defaultCenter] postNotificationName:kStoreManager_TransactionCompleteNotification
                                                                                                  object:self
                                                                                                userInfo:dict];
                                          }];
}

- (void) failedTransaction: (SKPaymentTransaction *)paymentTransaction
{
    NSError *error = paymentTransaction.error;
    if ( (error) && (error.code == SKErrorPaymentCancelled) )
        error = nil; // ignore user-cancelled errors
    
    NSMutableDictionary *dict =  @{@"paymentTransaction":  paymentTransaction}.mutableCopy;
    if (error)
        [dict setObject:error forKey:@"error"];
		
	// lookup userID from hash
	NSString *hashedUserName = paymentTransaction.payment.applicationUsername;
	NSString *userID = (hashedUserName) ? [[StoreManager sharedInstance] hashedObjectForKey:hashedUserName] : nil;
	if (userID)
		[dict setObject:userID forKey:@"userId"];

    [[NSNotificationCenter defaultCenter] postNotificationName:kStoreManager_TransactionCompleteNotification
                                                        object:self
                                                      userInfo:dict];

	// remove these or they will keep on showing up forever
	[[SKPaymentQueue defaultQueue] finishTransaction: paymentTransaction];
}

- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{
	// do we need to do anything here?
}

@end;


#define STORE_FAILURE_RETRY_INTERVAL		3

@interface StoreManager(Private)
- (NSDictionary *)allProductsMap;
- (void)_requestSKProductList;
- (void)_retryLoadProducts:(NSTimer *)t;
@end


@implementation StoreManager
{
    StoreObserver *storeObserver;
	NSMutableDictionary			*_hashMap;
}

// NOTE: implemented as a singleton
static StoreManager *sharedInstance;


+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[StoreManager alloc] init];
        [sharedInstance commonInit];
  	}
}

+ (StoreManager *)sharedInstance
{
	return sharedInstance;
}

-(void)commonInit
{
    // Apple recommends adding the Store Observer on App launch
	// store observer watches for any queued transactions to finish
	storeObserver = [[StoreObserver alloc] init];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:storeObserver];
	_hashMap = [[NSMutableDictionary alloc] initWithCapacity:1];
	_shouldRefreshProducts = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}

- (id)hashedObjectForKey:(id)key {
	return [_hashMap objectForKey:key];
}

#pragma mark - Purchasing

- (BOOL)startPurchaseProductID:(NSString *)productID
                       forUser:(SPUser *)user {
	if (!user) {
		NSLog(@"Start IAP: No user! User must be valid.");
		return NO;
	}
    ProductVO *prodVO = [_allProductsMap objectForKey:productID];
	if (!prodVO)
        return NO;
    
 	SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:prodVO.skProduct];
  	 
    // see Apple Notes "Detecting Irregular Activity" to add hashed version of username or user id
	payment.applicationUsername = [user.userID sha1];
	[_hashMap setObject:user.userID forKey:payment.applicationUsername];
	
    // start payment process: add the payment to iOS's payment queue
	[[SKPaymentQueue defaultQueue] addPayment:payment];
    
	return YES;
}

#pragma mark - All Products
- (NSArray *)allActiveProducts
{
	NSMutableArray *resultList = [NSMutableArray arrayWithCapacity:[_allProductsMap count]];
	for (ProductVO *prodVO in [_allProductsMap allValues]) {
		if (prodVO.skProduct != nil)
			[resultList addObject:prodVO];
	}
	return resultList;
}

- (NSArray *)allActiveProductsSortedByPrice
{
	return [[self allActiveProducts] sortedArrayUsingSelector:@selector(compareByPrice:)];
}

- (ProductVO *)productWithID:(NSString *)productID {
    return [_allProductsMap objectForKey:productID];
}

- (ProductVO *)productWithTag:(NSNumber *)tag {
	for (ProductVO *prodVO in [_allProductsMap allValues]) {
		if ([prodVO.tag isEqualToNumber:tag])
			return prodVO;
	}
	return nil;
}

// If we haven't fetched the products yet and we don't have an active request in-flight
// try to load them (check for Internet connectivity in the didFailWithError: delegate method
- (void)checkProducts {

    if(_shouldRefreshProducts && !_productRequest)
        [self loadAllProducts];
}

// Once the reachability status of the device has changed
// and the Internet is back, try to refetch the products
- (void)reachabilityChanged:(NSNotification *)note {
    
    if(!_shouldRefreshProducts)
        return;
    
    Reachability *reach = [Reachability reachabilityForInternetConnection];
    NetworkStatus reachabilityStatus = [reach currentReachabilityStatus];

    if(reachabilityStatus == NotReachable)
        return;
    
    [self checkProducts];
}

-(void)loadAllProducts
{
    // products are embedded in the App
    _allProductsMap = [NSMutableDictionary new];
	EmbeddedProductResponse *mockResponse = [EmbeddedProductResponse responseWithDefaultProductList];
	for (EmbeddedIAPProduct *product in mockResponse.products) {
		[_allProductsMap setObject:[product toProductVO] forKey:product.productIdentifier];
	}

    [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1Products
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              
                                            if(error)
                                                return;
                                              
                                            if(responseObject)
                                               [[UserService sharedService] updateProductListWithDictionary:(NSDictionary *)responseObject];
                                          }];
	
	// now load Store Kit products active on iTunes
	[self _requestSKProductList];
}

- (void)_requestSKProductList
{
    NSSet *productList = [NSSet setWithArray:[_allProductsMap allKeys]];
    if (_newProductList)
        productList = [productList setByAddingObjectsFromSet:_newProductList];
    
#if !TARGET_IPHONE_SIMULATOR
	_productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productList];
	_productRequest.delegate = self;
	[_productRequest start];
#else
	// simulator:
	[self productsRequest:_productRequest didReceiveResponse:[EmbeddedProductResponse responseWithDefaultProductList]];
#endif
}

- (void)_retryLoadProducts:(NSTimer *)t
{
    [self _requestSKProductList];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    _shouldRefreshProducts = NO;
	_productRequest = nil;
	
    NSArray *allProducts = response.products;
    
	if (allProducts == nil)
		NSLog(@"No products were found at iTunes Store!");

	NSMutableDictionary *finalProductsMap = [[NSMutableDictionary alloc] initWithCapacity:[allProducts count]];
	
	BOOL gotProducts = NO;
    
	for (SKProduct *skProduct in allProducts) {

        gotProducts = YES;
		
		ProductVO *existingProduct = [_allProductsMap valueForKey:skProduct.productIdentifier];
		if (existingProduct == nil) {// || [existingProduct wasModifiedOnServer]) {
			// this was not a product returned
			NSLog(@"AppStore provided product that we do not recognize (skipping): %@", skProduct.productIdentifier);
			continue;
		}
		else
			[existingProduct setSKProduct:skProduct];
		[finalProductsMap setObject:existingProduct forKey:skProduct.productIdentifier];
	}
	
	if (!gotProducts)
		NSLog(@"AppStore did not return any products!");

	_allProductsMap = finalProductsMap;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kStoreManager_ProductsLoadedNotification object:self];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"%s %@\nRequest: %@", __PRETTY_FUNCTION__, error, request);

	if (request == _productRequest)
	{
		_productRequest = nil;
	}

    // If the device has gone offline then we will receive a NSNotification once its
    // reachability status will change and the reachabilityChanged: method will get called
    if(error.userInfo && [error.userInfo objectForKey:NSUnderlyingErrorKey]) {
        
        NSError *underlyingError = [error.userInfo objectForKey:NSUnderlyingErrorKey];
        
        if(underlyingError.code == NSURLErrorNotConnectedToInternet)
            return;
    }
    
#if !TARGET_IPHONE_SIMULATOR
    
    // If it's a different error other than Internet connectivity
    // then we will keep trying (indefinitely?) till the request succeeds
    NSLog(@"%s - Retry in %d seconds", __PRETTY_FUNCTION__, STORE_FAILURE_RETRY_INTERVAL);
    
    [NSTimer scheduledTimerWithTimeInterval:STORE_FAILURE_RETRY_INTERVAL
                                     target:self
                                   selector:@selector(_retryLoadProducts:)
                                   userInfo:nil
                                    repeats:NO];
#endif
}

- (void)requestDidFinish:(SKRequest *)request
{
}

@end
