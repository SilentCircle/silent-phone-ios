//
//  SCSSearchVMHeaderFooterView.h
//  SPi3
//
//  Created by Stelios Petrakis on 15/02/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCSSearchVMHeaderFooterView : UITableViewHeaderFooterView

@property (weak, nonatomic) IBOutlet UILabel *mainTitle;
@property (weak, nonatomic) IBOutlet UILabel *subtitle;

+ (NSString *)reusedId;

@end
