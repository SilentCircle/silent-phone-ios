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
#define kZoomDistance 800
#define kBackButtonSize 30

#import "MapViewController.h"
#import "ChatObject.h"
#import "LocationManager.h"
#import "Utilities.h"

typedef enum {
    infoActionSheet = 0,
    optionsActionSheet
} ActionSheetOption;

@interface MapViewController ()
{    
    ActionSheetOption actionSheetOption;
    
}
@end

@implementation MapViewController

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setTitle:@"Location"];
    
    // transparent black background view for status bar
    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, [Utilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[Utilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    UIButton *backButtonWithImage = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButtonWithImage setFrame:CGRectMake(0,0,kBackButtonSize,kBackButtonSize)];
    backButtonWithImage.userInteractionEnabled = YES;
    [backButtonWithImage setImage:[UIImage imageNamed:@"BackButton.png"] forState:UIControlStateNormal];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    [_mapView setMapType:[Utilities utilitiesInstance].savedMapType];
    
    if([Utilities utilitiesInstance].savedShowLocationState == 1)
    {
        _mapView.showsUserLocation = YES;
    } else
    {
        _mapView.showsUserLocation = NO;
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // change region first, so drop animation could be seen
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(_pinLocation.coordinate, kZoomDistance, kZoomDistance);
    [_mapView setRegion:[_mapView regionThatFits:region] animated:YES];
    
    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate = _pinLocation.coordinate;
    pin.title = _locationUserName;
    pin.subtitle = [[Utilities utilitiesInstance] takeTimeFromDateStamp:_locationUnixTimeStamp];
    [_mapView addAnnotation:pin];
    // automatically select pin to open callout
    [_mapView selectAnnotation:pin animated:YES];
}

-(void) calloutDetailButtonClick:(UIButton*) button
{
    UIActionSheet *actSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Coordinates for %@",_locationUserName] delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Open in Maps",@"Copy", nil];
    actSheet.delegate = self;
    [actSheet showInView:self.view];
    actionSheetOption = infoActionSheet;
}

#pragma mark MKMapViewDelegate
- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id ) annotation
{
    MKPinAnnotationView *ann = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"userAnnotation"];
    ann.animatesDrop = YES;
    ann.canShowCallout = YES;
    UIButton *detailButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    [detailButton addTarget:self action:@selector(calloutDetailButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    ann.rightCalloutAccessoryView = detailButton;
    return ann;
}
/*
-(void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
    // replace chatObject image with rendered
    NSMutableArray *thisUsersChatObjects = [[[Utilities utilitiesInstance].chatHistory objectForKey:@"userid"] mutableCopy];
    ChatObject *thisChatObject = (ChatObject*) thisUsersChatObjects[_chatItemIndexPath.row];
    if(!thisChatObject.isLocationImageSet)
    {
        thisChatObject.image = [self getPinScreenShot];
        thisChatObject.isLocationImageSet = YES;
        [thisUsersChatObjects replaceObjectAtIndex:_chatItemIndexPath.row withObject:thisChatObject];
        [[Utilities utilitiesInstance].chatHistory setValue:thisUsersChatObjects forKey:@"userid"];
    }
}
 

// get screenshot of MapView and pin
-(UIImage *) getPinScreenShot
{
    //Make an UIImage from view
    UIGraphicsBeginImageContext(self.view.bounds.size);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *sourceImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //position the image, X/Y away from top left corner to get the portion with pin in center
    UIGraphicsBeginImageContext(CGSizeMake(200, 200));
    [sourceImage drawAtPoint:CGPointMake(-320/2 + 100, -568/2 + 100)];
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}
*/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (IBAction)mapOptionsClick:(id)sender {
    NSString *locationAction;
    if([Utilities utilitiesInstance].savedShowLocationState == 0)
    {
        locationAction = @"Show My Location";
    } else
    {
        locationAction = @"Dont show My Location";
    }
    actionSheetOption = optionsActionSheet;
    UIActionSheet *mapOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:@"Map Options" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Map", @"Satellite",@"Hybrid",locationAction, nil];
    [mapOptionsActionSheet showInView:self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(actionSheetOption == optionsActionSheet)
    {
        switch (buttonIndex) {
            case 0:
            {
                if(_mapView.mapType != MKMapTypeStandard)
                {
                    [_mapView setMapType:MKMapTypeStandard];
                    [Utilities utilitiesInstance].savedMapType = MKMapTypeStandard;
                    [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%i",MKMapTypeStandard] forKey:@"savedMapType"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
                break;
            case 1:
            {
                if(_mapView.mapType != MKMapTypeSatellite)
                {
                    [_mapView setMapType:MKMapTypeSatellite];
                    [Utilities utilitiesInstance].savedMapType = MKMapTypeSatellite;
                    [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%i",MKMapTypeSatellite] forKey:@"savedMapType"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
                break;
            case 2:
            {
                if(_mapView.mapType != MKMapTypeHybrid)
                {
                    [_mapView setMapType:MKMapTypeHybrid];
                    [Utilities utilitiesInstance].savedMapType = MKMapTypeHybrid;
                    [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%i",MKMapTypeHybrid] forKey:@"savedMapType"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }
                break;
            case 3:
            {
                if([Utilities utilitiesInstance].savedShowLocationState == 0)
                {
                    _mapView.showsUserLocation = YES;
                    [Utilities utilitiesInstance].savedShowLocationState = 1;
                    [[LocationManager locationManagerInstance].locationManager startUpdatingLocation];
                } else
                {
                    _mapView.showsUserLocation = NO;
                    [Utilities utilitiesInstance].savedShowLocationState = 0;
                    [[LocationManager locationManagerInstance].locationManager stopUpdatingLocation];
                }
                [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%i",[Utilities utilitiesInstance].savedShowLocationState] forKey:@"savedShowLocationState"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
            }
                break;
                
            default:
                break;
        }
    } else
    {
        switch (buttonIndex) {
            case 0:
            {
                MKPlacemark *placeMark = [[MKPlacemark alloc] initWithCoordinate:_pinLocation.coordinate addressDictionary:nil];
                MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placeMark];
                
                NSMutableDictionary *launchOptions = [[NSMutableDictionary alloc] init];
                [launchOptions setObject:MKLaunchOptionsDirectionsModeWalking forKey:MKLaunchOptionsDirectionsModeKey];
                
                [mapItem openInMapsWithLaunchOptions:launchOptions];
            }
                break;
            case 1:
            {
                NSString *pasteBoardString = [NSString stringWithFormat:@"Location of %@:\n Latitude: %f\n Longitude: %f\n Altitude: %f",_locationUserName,_pinLocation.coordinate.latitude,_pinLocation.coordinate.longitude,_pinLocation.altitude];
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = pasteBoardString;
            }
                break;
                
            default:
                break;
        }
    }
}

/*
 UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
 if(!cell.imageView.image)
 {
 pasteboard.string = cell.messageTextLabel.text;
 }
 */
@end
