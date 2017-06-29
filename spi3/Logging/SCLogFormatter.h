//
//  SCLogFormatter.h
//  SPi3
//
//  Created by Eric Turner on 2/24/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

@interface SCLogFormatter : NSObject <DDLogFormatter>
{ 
    BOOL useTimestamp;
}

- (instancetype)initUsingTimestamp;

@end
