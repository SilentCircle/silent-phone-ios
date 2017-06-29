/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

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
#import "ChatUtilities.h"

@implementation MapViewController

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self setTitle:NSLocalizedString(@"Location", nil)];
    
    // transparent black background view for status bar
    //UIView *darkTopView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [ChatUtilities utilitiesInstance].screenWidth, [ChatUtilities utilitiesInstance].kStatusBarHeight)];
    //[darkTopView setBackgroundColor:[ChatUtilities utilitiesInstance].kStatusBarColor];
    //[self.view addSubview:darkTopView];
    
    UIButton *backButtonWithImage = [ChatUtilities getNavigationBarBackButton];
    [backButtonWithImage addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backBarButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonWithImage];
    self.navigationItem.leftBarButtonItem = backBarButton;
    
    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    [infoButton addTarget:self
                   action:@selector(mapOptionsClick:)
         forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *infoBarButton = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
    UIBarButtonItem *shareBarButton= [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(calloutDetailButtonClick:)];
    self.navigationItem.rightBarButtonItems = @[shareBarButton, infoBarButton];
    
    [_mapView setMapType:(MKMapType)[ChatUtilities utilitiesInstance].savedMapType];
    
    if([ChatUtilities utilitiesInstance].savedShowLocationState == 1)
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
    pin.subtitle = [[ChatUtilities utilitiesInstance] takeTimeFromDateStamp:_locationUnixTimeStamp];
    [_mapView addAnnotation:pin];
    // automatically select pin to open callout
    [_mapView selectAnnotation:pin animated:YES];
}

#pragma mark - Accessibility

-(BOOL) accessibilityPerformEscape
{
    [self.navigationController popViewControllerAnimated:YES];
    
    return YES;
}

-(void) calloutDetailButtonClick:(UIButton*) button
{
    UIAlertController *alertC = [UIAlertController
                                 alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Coordinates for %@", nil),_locationUserName]
                                 message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alertC addAction:cancelAction];

    UIAlertAction *openAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in Maps", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        MKPlacemark *placeMark = [[MKPlacemark alloc] initWithCoordinate:_pinLocation.coordinate addressDictionary:nil];
        MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placeMark];
        [mapItem openInMapsWithLaunchOptions:nil];
    }];
    [alertC addAction:openAction];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *pasteBoardString = [NSString stringWithFormat:NSLocalizedString(@"Location of %@:\n Latitude: %f\n Longitude: %f\n Altitude: %f", nil),_locationUserName,_pinLocation.coordinate.latitude,_pinLocation.coordinate.longitude,_pinLocation.altitude];
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = pasteBoardString;
    }];
    [alertC addAction:copyAction];
    
    [self presentViewController:alertC animated:YES completion:nil];
    
//    UIActionSheet *actSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Coordinates for %@", nil),_locationUserName] delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Open in Maps", nil), NSLocalizedString(@"Copy", nil), nil];
//    actSheet.delegate = self;
//    [actSheet showInView:self.view];
//    actionSheetOption = infoActionSheet;
}

#pragma mark MKMapViewDelegate
- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id ) annotation
{
    MKPinAnnotationView *ann = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"userAnnotation"];
    ann.animatesDrop = YES;
    ann.canShowCallout = YES;
    return ann;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
- (IBAction)mapOptionsClick:(id)sender {
    NSString *locationActionS = ([ChatUtilities utilitiesInstance].savedShowLocationState == 0) ?
            NSLocalizedString(@"Show My Location", nil) : NSLocalizedString(@"Dont show My Location", nil);
    
    UIAlertController *alertC = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Map Options", nil)
                                 message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil];
    [alertC addAction:cancelAction];

    UIAlertAction *mapAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Map", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if(_mapView.mapType != MKMapTypeStandard)
        {
            [_mapView setMapType:MKMapTypeStandard];
            [ChatUtilities utilitiesInstance].savedMapType = MKMapTypeStandard;
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lu",(unsigned long)MKMapTypeStandard] forKey:@"savedMapType"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    [alertC addAction:mapAction];
    
    UIAlertAction *satAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Satellite", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if(_mapView.mapType != MKMapTypeSatellite)
        {
            [_mapView setMapType:MKMapTypeSatellite];
            [ChatUtilities utilitiesInstance].savedMapType = MKMapTypeSatellite;
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lu",(unsigned long)MKMapTypeSatellite] forKey:@"savedMapType"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    [alertC addAction:satAction];

    UIAlertAction *hybridAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Hybrid", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if(_mapView.mapType != MKMapTypeHybrid)
        {
            [_mapView setMapType:MKMapTypeHybrid];
            [ChatUtilities utilitiesInstance].savedMapType = MKMapTypeHybrid;
            [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%lu",(unsigned long)MKMapTypeHybrid] forKey:@"savedMapType"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
    [alertC addAction:hybridAction];

    UIAlertAction *locationAction = [UIAlertAction actionWithTitle:locationActionS style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if([ChatUtilities utilitiesInstance].savedShowLocationState == 0)
        {
            _mapView.showsUserLocation = YES;
            [ChatUtilities utilitiesInstance].savedShowLocationState = 1;
            [[LocationManager sharedManager] startUpdatingLocation];
        } else
        {
            _mapView.showsUserLocation = NO;
            [ChatUtilities utilitiesInstance].savedShowLocationState = 0;
            [[LocationManager sharedManager] stopUpdatingLocation];
        }
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%i",[ChatUtilities utilitiesInstance].savedShowLocationState] forKey:@"savedShowLocationState"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    [alertC addAction:locationAction];

    [self presentViewController:alertC animated:YES completion:nil];
}

/*
 UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
 if(!cell.imageView.image)
 {
 pasteboard.string = cell.messageTextLabel.text;
 }
 */
@end
