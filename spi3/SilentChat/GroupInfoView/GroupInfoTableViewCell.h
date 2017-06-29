//
//  GroupInfoTableViewCell.h
//  SPi3
//
//  Created by Gints Osis on 20/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GroupInfoTextField.h"

@interface GroupInfoTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet GroupInfoTextField *valueTextField;
+(NSString *) reuseIdentifier;
@end
