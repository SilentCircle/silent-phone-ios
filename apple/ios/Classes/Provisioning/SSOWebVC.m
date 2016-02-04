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

#import "SSOWebVC.h"

@interface SSOWebVC ()

@end


@implementation SSOWebVC
{
    NSMutableURLRequest *_urlRequest;
}


+ (SSOWebVC *)ssoWebVCWithURL:(NSURL *)inURL delegate:(id<UIWebViewDelegate>)del {
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
    SSOWebVC *webVC = [sb instantiateViewControllerWithIdentifier:NSStringFromClass([self class])];
    if (!webVC) return nil;
    
    webVC.webDelegate = del;
    webVC.url = inURL;
    
    return webVC;
}

- (void)dealloc {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set webView delegate
    self.webView.delegate = _webDelegate;
    
    //load url into webview
    _urlRequest = [NSMutableURLRequest requestWithURL:_url];
    _urlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    _urlRequest.timeoutInterval = 15.0;
    [self.webView loadRequest:_urlRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
