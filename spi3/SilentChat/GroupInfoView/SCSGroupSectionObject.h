//
//  SCSGroupSectionObject.h
//  SPi3
//
//  Created by Gints Osis on 20/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCSEnums.h"
@interface SCSGroupSectionObject : NSObject

@property (nonatomic) scsGroupInfoSectionType sectionType;

@property (nonatomic, strong) NSString *headerTitle;
@property (nonatomic, strong) NSArray *objectsArray;

@end
