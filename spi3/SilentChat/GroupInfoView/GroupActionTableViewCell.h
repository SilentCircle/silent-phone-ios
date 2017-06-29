//
//  GroupActionTableViewCell.h
//  SPi3
//
//  Created by Gints Osis on 05/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol GroupActionDelegate<NSObject>
-(void) leaveGroupTapped;
@end
@interface GroupActionTableViewCell : UITableViewCell
+(NSString *) reuseIdentifier;
- (IBAction)leaveGroupAction:(id)sender;

@property (nonatomic, assign) id <GroupActionDelegate> delegate;
@end
