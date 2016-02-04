/*
Copyright (C) 2014-2015, Silent Circle, LLC.  All rights reserved.

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

#import "ZIDViewController.h"

#include <libzrtpcpp/ZIDCache.h>

static int iZidViewIsVisible=0;


@interface ZIDPeer : NSObject{
@public int zrtp_flags;
}

@property (nonatomic, strong) NSString *local_zid;
@property (nonatomic, strong) NSString *zid;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *secure_since;
@property (nonatomic, strong) NSString *rs1;
@property (nonatomic, strong) NSString *rs2;
@property (nonatomic, strong) NSString *rs1_ttl;
@property (nonatomic, strong) NSString *rs2_ttl;
@property (nonatomic, strong) NSString *rs1_lu;
@property (nonatomic, strong) NSString *rs2_lu;
@property (nonatomic, strong) NSString *pbx;
@property (nonatomic, strong) NSString *pbx_lu;

@end

@implementation ZIDPeer

@synthesize local_zid, zid, name, secure_since, rs1, rs2, rs1_ttl, rs2_ttl, pbx;
@synthesize rs1_lu, rs2_lu, pbx_lu;

@end

@interface ZIDViewController ()

@end

@implementation ZIDViewController

@synthesize ownZID;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
       iZidViewIsVisible=1;
        // Custom initialization
       [self loadData];
    }
    return self;
}
+(int)isZIDVisible{return iZidViewIsVisible;}

- (void)viewDidLoad
{

    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
}
-(BOOL)prefersStatusBarHidden{return YES;}
/*
- (void)viewWillAppear:(BOOL)animated{
   [super viewWillAppear:animated];
   if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
      self.setNeedsStatusBarAppearanceUpdate
      CGRect viewBounds = [self.view bounds];
      viewBounds.origin.y = 20;
      viewBounds.size.height = viewBounds.size.height - 20;
      self.view.frame = viewBounds;
   }
}
 */
- (void)viewDidAppear:(BOOL)animated{


   [ni setTitle:ownZID];
   [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated{
   [super viewDidDisappear:animated];
   [peerList removeAllObjects];
   [peerList release];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(NSString *)convertTimeNS:(id)obj{
   
   NSString *dst;
   NSString *int_str = obj;
   //longLongValue
   int t = atoi(int_str.UTF8String);
   if(t==0)
      dst =  @"";
   else if(t==-1)
      dst =  @"forever";
   else
   {
      void insertTimeDateFriendly(char  *buf, int iTime, int utc);
      char buf[64];
      insertTimeDateFriendly(buf,t,1);
      dst = [NSString stringWithUTF8String:buf];
   }
   return dst;
   
}

-(void)parseAddToList:(const char *)line{
   
   NSString *str = [NSString stringWithUTF8String:line];
   NSArray *a = [str componentsSeparatedByString:@"|"];
   if(!a || a.count<12)return;
   ZIDPeer *peer;
   peer = [[ZIDPeer alloc] init ];
   
   self.ownZID = a[0]; //TODO verify
   
   peer.local_zid = a[0];
   
   peer.zid = a[1];
   peer.secure_since = [self convertTimeNS:a[11]];
   peer.name =a[12];
   
   peer.rs1 = a[3];
   peer.rs1_lu = [self convertTimeNS:a[4]];
   peer.rs1_ttl = [self convertTimeNS:a[5]];
   
   peer.rs2 = a[6];
   peer.rs2_lu = [self convertTimeNS:a[7]];
   peer.rs2_ttl = [self convertTimeNS:a[8]];
  
   peer.pbx = a[9];
   peer.pbx_lu = [self convertTimeNS:a[10]];
   
   NSString *nf= a[2];
   
   peer->zrtp_flags = (int)strtol(nf.UTF8String, 0, 16);
   
  
   
   

   /*
    peer.name = @"Abele";
    peer.zid = @"13ab232";
    peer.secure_since = @"12-dec-2013";
    
    */

   
   [peerList addObject:peer];
   
}

-(void)loadData{
   peerList = [[NSMutableArray alloc] init];
   

   
   ZIDCache* zf = getZidCacheInstance();
   void *stmnt = zf->prepareReadAll();
   if (stmnt != NULL) {
      std::string name;
      do {
         stmnt = zf->readNextRecord(stmnt, &name);
         if(!stmnt)
            break;
      //   fprintf(stderr, "Record: %s\n", name.c_str());
         
         [self parseAddToList: name.c_str()];
         
      } while (1);
   }
   else {
      fprintf(stderr, "Cannot prepare for readAll\n");
   }
  
   
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
   return 44.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
   return peerList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
   
   static NSString *CellIdentifier = @"tmp_zid_cell";
   UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

   if(cell == nil)
   {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
      
   }

   ZIDPeer *peer = [peerList objectAtIndex:indexPath.row];
   cell.textLabel.text = peer.name;
   cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", peer.secure_since, peer.zid];
   
   int f = peer->zrtp_flags;
   
   int ok = (f & 0x1) &&  (f & 0x2) &&  (f & 0x4)
   &&  ((f & 0x10)==0) ;
   
   cell.textLabel.textColor = ok?  [UIColor greenColor] : [UIColor blackColor];
   
   return cell;
   
}

-(NSString *)addField:(NSString *)dst s:(NSString *)s v:(NSString *)v{
    if(v == nil || v.length<1)return  [dst stringByAppendingFormat:@"%@: 'empty'\n",s];
    return [dst stringByAppendingFormat:@"%@: %@\n",s,v];
}

-(NSString *)obfuscateRS:(NSString *)ns{
   
   void sha256(unsigned char *data,
               unsigned int data_length,
               unsigned char *digest);
   
   void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
//   int hex2BinL(unsigned char *Bin, char *Hex, int iLen);
   
   //unsigned char bin[64];
   unsigned char h_result[128];// > SHA256_DIGEST_SIZE
   
  // int binLen = hex2BinL(&bin[0], (char *)ns.UTF8String, ns.length);
   sha256((unsigned char *)ns.UTF8String, (unsigned int)ns.length, h_result);
   
   char result[128];
   
   bin2Hex(h_result, result, 6);//return 48 bits
   
   return [NSString stringWithUTF8String:result];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
   ZIDPeer *peer = [peerList objectAtIndex:indexPath.row];
   
   char flags[256];
   
   int f = peer->zrtp_flags;
   int l = 0;
   if((f&0x1)==0)l += snprintf(&flags[l], sizeof(flags)-l, "Not Valid,");
   if(f&0x2)l += snprintf(&flags[l], sizeof(flags)-l, " Verified,");
   if(f&0x4)l += snprintf(&flags[l], sizeof(flags)-l, " RS1,");
   if(f&0x8)l += snprintf(&flags[l], sizeof(flags)-l, " RS2,");
   if(f&0x10)l += snprintf(&flags[l], sizeof(flags)-l, " PBX_KEY,");
   if(l){l--;flags[l]=0;}
  // if((f&0x20)==0)l += snprintf(&flags[l], sizeof(flags)-l, " not_inUse");
   
   NSString *e=@"";
   e = [self addField:e s:@"Name"  v:peer.name];
   e = [self addField:e s:@"Secure since"  v:peer.secure_since];
   
   e = [self addField:e s:@"Flags"  v:[NSString stringWithUTF8String:flags ]];

   e = [self addField:e s:@"Remote ZID"  v:peer.zid];
   e = [e stringByAppendingString:@"\n"];

   if(f&0x4){
      e = [self addField:e s:@"H(RS1)"  v:[self obfuscateRS:peer.rs1]];
      if(peer.rs1_lu && peer.rs1_lu.length)e = [self addField:e s:@"Last used" v:peer.rs1_lu];
      e = [self addField:e s:@"TTL: " v:peer.rs1_ttl];
      e = [e stringByAppendingString:@"\n"];
   }
   
   if(f&0x8){
      e = [self addField:e s:@"H(RS2)"  v:[self obfuscateRS:peer.rs2]];
      if(peer.rs2_lu && peer.rs2_lu.length)e = [self addField:e s:@"Last used" v:peer.rs2_lu];
      e = [self addField:e s:@"TTL: " v:peer.rs2_ttl];
      e = [e stringByAppendingString:@"\n"];
   }
   
   if(f&0x10){
      e = [self addField:e s:@"H(PBX_key)"  v:[self obfuscateRS:peer.pbx]];
      if(peer.pbx_lu && peer.pbx_lu.length)e = [self addField:e s:@"Last used: " v:peer.pbx_lu];
   }

   
   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:peer.local_zid
                                                   message:e
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
   alert.delegate = self;
   [alert show];
   [alert release];
   
   //tw.alpha = 0.0f;
   [tw setHidden:YES];
   
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
   //tw.alpha = 1.0f;
    [tw setHidden:NO];
}



-(IBAction)onBackPress:(id)sender{

   [self dismissViewControllerAnimated:YES completion:^(){iZidViewIsVisible=0;}];

}

@end
