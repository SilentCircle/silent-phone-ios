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
#import "SilentContactInfoViewController.h"
#import "ContactInfoCell.h"
@implementation SilentContactInfoViewController

#pragma mark UITableViewDelegate

-(void)viewWillAppear:(BOOL)animated
{
    _contactUsername.text = _selectedUserContact.contactFullName;
    _contactImageView.image = _selectedUserContact.contactImage;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    // should add sections for alphabetical character headers
    return 1;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
    return _selectedUserContact.contactPhones.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = @"callCell";
    ContactInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    NSDictionary *contactPhones = _selectedUserContact.contactPhones[indexPath.row];
    
    cell.phoneLabel.text = [contactPhones objectForKey:@"phoneLabel"];
    cell.phoneNumberLabel.text = [contactPhones objectForKey:@"phoneNumber"];
    /*
    UserContact *thisContact = searchContactData[indexPath.row];
    cell.contactImage.image = thisContact.contactImage;
    cell.contactName.text = thisContact.contactFullName;
     */
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   /* UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Contacts" bundle:nil];
    UIViewController *contactInfoViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ContactInfoViewController"];
    
    [self.navigationController pushViewController:contactInfoViewController animated:YES];*/
}

@end
