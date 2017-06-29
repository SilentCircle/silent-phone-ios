//
//  SCAvatar.h
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCAvatar.h"
#import "RecentObject.h"
@interface SCAvatar : NSObject

// full avatar image 512x512
@property (nonatomic, strong,setter=setAvatarImage:) UIImage *avatarImage;

// Scaled down version of avatarImage used in UiTableView cells
// 150x150 in size
@property (nonatomic, strong) UIImage *smallAvatarImage;


// use strong reference but set it to nil once avatar finding is done
@property (nonatomic, strong) RecentObject *conversation;

@property BOOL isDownloadingAvatar;

@end
