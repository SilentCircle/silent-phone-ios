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
#import "VoiceRecorderView.h"
#import "SCFileManager.h"
#import "SnippetGraphView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import "SCPNotificationKeys.h"

@interface VoiceRecorderView () {
    NSTimer * _updateTimer;
    NSURL   *_url;
}

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer   *audioPlayer;
@property (nonatomic, strong) NSString *prevCategory;
@property (nonatomic, assign) AVAudioSessionCategoryOptions prevOptions;

@property (nonatomic, weak) IBOutlet UIButton *recordButton;
@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (nonatomic, weak) IBOutlet UIButton *sendButton;
@property (nonatomic, weak) IBOutlet UIImageView *redLEDImageView;
@property (weak, nonatomic) IBOutlet UIImageView *blueLEDImageView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIImageView *controlbarImageView;
@property (weak, nonatomic) IBOutlet UILabel *recordingLength;
@property (weak, nonatomic) IBOutlet SnippetGraphView *sgView;
@property (weak, nonatomic) IBOutlet UIView *backgroundShade;

- (IBAction)recordAction:(id)sender;
- (IBAction)playAction:(id)sender;
- (IBAction)cancelAction:(id)sender;
- (IBAction)sendAction:(id)sender;

- (BOOL)isVisible;

@end

@implementation VoiceRecorderView

+ (BOOL) canRecord
{
    return YES;
}

- (id)init
{
    NSArray *nibArray = [[NSBundle mainBundle] loadNibNamed:@"VoiceRecorderView" owner:self options:nil];
    self = [nibArray firstObject];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willPresentCallScreen:) name:kSCPWillPresentCallScreenNotification object:nil];
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) willPresentCallScreen:(NSNotification *) notification
{
    // stop recording if user receives an incoming call
    if (_audioRecorder.recording)
        [self recordAction:nil];
}

-(BOOL) setupRecorderWithError: (NSError **)error
{
    [_playButton  setEnabled:NO];
    [_sendButton  setEnabled:NO];
    [_redLEDImageView setHidden:YES];
    [_blueLEDImageView setHidden:YES];
    _recordButton.accessibilityLabel = @"Record";
    
    _audioRecorder = nil;
    _audioPlayer = nil;
    return YES;
}

- (void) unfurlOnView:(UIView*)view atPoint:(CGPoint) point
{
    NSError*  error = NULL;
    
    if ([self superview]) {
        return;
    }
    
    view.tintColor = view.superview.tintColor;
    _cancelButton.tintColor = _sendButton.tintColor = view.tintColor;
    [_sgView reset];
    _sgView.clipsToBounds = YES;
    _sgView.backgroundColor = [UIColor blackColor];
    _sgView.layer.borderColor = [UIColor whiteColor].CGColor;
    _sgView.layer.borderWidth = 1;
    _sgView.waveColor = [UIColor redColor];
    
    if(![self setupRecorderWithError: &error])
    {
        if ([_delegate respondsToSelector:@selector(voiceRecorderView:didFinishRecordingAttachment:error:)])
            [_delegate voiceRecorderView:self didFinishRecordingAttachment:NULL error:error];
    }
    else
    {
        self.frame = CGRectMake(0,
                                view.bounds.size.height,
                                view.bounds.size.width,
                                view.bounds.size.height);
        self.alpha = 0.0;
        _backgroundShade.alpha = 0.0;
        [view addSubview:self];
        [UIView animateWithDuration:0.5f
                         animations:^{
                             [self setAlpha:1.0];
                             self.frame = CGRectMake(0,
                                                     0,
                                                     view.bounds.size.width,
                                                     view.bounds.size.height);
                             
                             
                         }
                         completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25f animations:^{
                                 _backgroundShade.alpha = 1.0;
                             }];
                         }];
    }
}

- (void) deleteAudioFile
{
    [_audioRecorder deleteRecording];
    // the following is for redundancy.  It's important to delete the sound file and not leave any behind
    _audioRecorder = nil;
    if (_url)
    {
        NSString *filePath = [_url path];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        if( filePath && [fm fileExistsAtPath:filePath]) {
            [fm removeItemAtPath:filePath error:nil];
        }
        _url = nil;
    }
}

- (void) fadeOut
{
    UIView *parentView = self.superview;
    self.frame = CGRectMake(0,
                            0,
                            parentView.bounds.size.width,
                            parentView.bounds.size.height);
    [UIView animateWithDuration:0.25f
                     animations:^{
                         _backgroundShade.alpha = 0.0;
                         
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.5f animations:^{
                             [self setAlpha:0.0];
                             self.frame = CGRectMake(0,
                                                     parentView.bounds.size.height,
                                                     parentView.bounds.size.width,
                                                     parentView.bounds.size.height);
                             
                         }
                                          completion:^(BOOL finished) {
                                              [self removeFromSuperview];
                                              
                                          }];
                     }];
    
}

- (BOOL) isVisible
{
    return [self superview] ? YES : NO;
}

- (void) hide
{
    [self stopTimer];
    [self stopRecording];
    
    [self deleteAudioFile];
    
    if (_audioRecorder) {
        
        _audioRecorder = nil;
        _audioRecorder.delegate = nil;
    }
    
    if (_audioPlayer) self.audioPlayer = NULL;
    
    [self fadeOut];
}

- (void) stopPlay
{
    [_audioPlayer stop];
    [_playButton setSelected:NO];
    [_blueLEDImageView setHidden:YES];
}

- (void)stopRecording {
    if (_audioRecorder) {
        if (_audioRecorder.isRecording)
            [_audioRecorder stop];
    }
    
    [self resetSessionCategory];
}

- (void)resetSessionCategory {
    
    if (!self.prevCategory)
        return;

    NSError *error = nil;
    
    [[AVAudioSession sharedInstance] setCategory:self.prevCategory
                                     withOptions:self.prevOptions
                                           error:&error];
    
    if(error)
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
    
    self.prevCategory = nil;
}

- (IBAction)recordAction:(id)sender
{
    if (!_audioRecorder.recording)
    {
        [self stopPlay];
        _audioPlayer = nil;
        [self deleteAudioFile];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        self.prevCategory = session.category;
        self.prevOptions = session.categoryOptions;
        
        NSDictionary *recordSettings = @{
                                         AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                         AVEncoderBitRateStrategyKey: AVAudioBitRateStrategy_LongTermAverage,
                                         AVEncoderAudioQualityKey : @(AVAudioQualityMedium),
                                         AVNumberOfChannelsKey : @1,
                                         AVSampleRateKey : @16000.0
                                         };
        
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyyMMdd-HHmmss"];
        format.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        
        NSString *filename = [NSString stringWithFormat:@"%@.m4a", [format stringFromDate:NSDate.date]];
        
        _url = [[SCFileManager recordingCacheDirectoryURL] URLByAppendingPathComponent:filename];
        
        _audioRecorder = [[AVAudioRecorder alloc]
                          initWithURL:_url
                          settings:recordSettings
                          error:nil];
        
        if (_audioRecorder != NULL) {
            NSError *avError = nil;
            [session setCategory:AVAudioSessionCategoryPlayAndRecord
                     withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth)
                           error:&avError];
            
            if (avError) {
                NSLog(@"%s\n\tsession setup error: %@ at line %d",
                      __PRETTY_FUNCTION__,[avError localizedDescription], __LINE__);
            }
            
            _audioRecorder.delegate = self;
            [_audioRecorder prepareToRecord];
            [_sgView reset];
            _audioRecorder.meteringEnabled = YES;
            
            [_audioRecorder recordForDuration:900.0];
            [_playButton setEnabled:NO];
            [_sendButton setEnabled:NO];
            [_recordButton setSelected:YES];
            
            
            [_redLEDImageView setHidden:NO];
            
            CABasicAnimation *theOpacityAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
            theOpacityAnimation.duration=0.7;
            theOpacityAnimation.repeatCount=HUGE_VALF;
            theOpacityAnimation.autoreverses=YES;
            theOpacityAnimation.fromValue=[NSNumber numberWithFloat:1.0];
            theOpacityAnimation.toValue=[NSNumber numberWithFloat:0.25];
            [_redLEDImageView.layer addAnimation:theOpacityAnimation forKey:@"animateOpacity"]; //
            [self startTimer];
        }
        _recordButton.accessibilityLabel = NSLocalizedString(@"Stop", nil);
    }
    else
    {
        [self stopRecording];
    }
}

- (void) loadAudioFile
{
    NSError *error;
    if (!_audioPlayer) {
        _audioPlayer = [[AVAudioPlayer alloc]
                        initWithContentsOfURL:_audioRecorder.url
                        error:&error];
        
        if(error)
            NSLog(@"Error: %@",   [error localizedDescription]);
        
        if (!_audioPlayer) {
            NSData *soundData = [[NSData alloc] initWithContentsOfURL:_audioRecorder.url];
            _audioPlayer = [[AVAudioPlayer alloc] initWithData: soundData
                                                         error: &error];
            
            if(error)
                NSLog(@"Error: %@",   [error localizedDescription]);
        }
        if (_audioPlayer) {
            _audioPlayer.delegate = self;
        }
        else {
            [_playButton setEnabled:NO];
            [_sendButton setEnabled:NO];
        }
    }
}

- (IBAction)playAction:(id)sender
{
    if (_audioPlayer)
    {
        if (!_audioPlayer.playing) {
            
            [self resetSessionCategory];
            
            [_sgView reset];
            
            _audioPlayer.meteringEnabled = YES;
            [self startTimer];
            [_audioPlayer play];
            [_playButton setSelected:YES];
            [_blueLEDImageView setHidden:NO];
        }
        else {
            [self stopPlay];
        }
    }
}

- (IBAction)cancelAction:(id)sender
{
    [self hide];
}

#pragma mark - AVAudioPlayerDelegate

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _audioPlayer.meteringEnabled = NO;
    
    [_playButton setSelected:NO];
    [_blueLEDImageView setHidden:YES];
    _recordButton.accessibilityLabel = NSLocalizedString(@"Record", nil);
}

-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"Decode Error occurred");
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    _audioRecorder.meteringEnabled = NO;
    [self updateUIForRecordingStop];
    [self loadAudioFile];
}

- (void) updateUIForRecordingStop
{
    _recordButton.accessibilityLabel = NSLocalizedString(@"Record", nil);
    [_playButton setEnabled:YES];
    [_sendButton setEnabled:YES];
    [_recordButton setSelected:NO];
    [_redLEDImageView setHidden:YES];
    [_redLEDImageView.layer removeAllAnimations];
}

-(void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    [self resetSessionCategory];
    
    [self updateUIForRecordingStop];
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder;
{
    [self audioRecorderDidFinishRecording: recorder successfully:YES];
}

- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder withOptions:(NSUInteger)flags
{
}

#define MAX_SOUND_WAVE_WIDTH 150
- (IBAction)sendAction:(id)sender
{
    [self stopRecording];
    
    NSInteger numOfPoints;
    unsigned char *soundWave = [_sgView getNativeGraphPoints:&numOfPoints];
    NSData *soundWaveData = [NSData dataWithBytes:soundWave length:MIN(numOfPoints, MAX_SOUND_WAVE_WIDTH)];
    
    SCAttachment *attachment = [SCAttachment attachmentFromAudioURL:_url soundWave:soundWaveData duration:_audioPlayer.duration];
    
    if ( (_delegate) && ([_delegate respondsToSelector:@selector(voiceRecorderView:didFinishRecordingAttachment:error:)]) )
        [_delegate voiceRecorderView:self didFinishRecordingAttachment:attachment error:nil];
    
    _audioPlayer = NULL;
    _audioRecorder = NULL;
    [self hide];
}

#pragma mark - Level Meter and Duration Updater

- (void)stopTimer
{
    [_updateTimer invalidate];
    _updateTimer = nil;
}

- (void)startTimer
{
    if (_updateTimer)
        [self stopTimer];
    
    _updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateSoundStatus) userInfo:nil repeats:YES];
}

- (void)updateSoundStatus
{
    id player;
    if (_audioRecorder.isRecording)
        player = (id) _audioRecorder;
    else
        player = (id) _audioPlayer;
    BOOL nothingHappening = !_audioPlayer.isPlaying && !_audioRecorder.isRecording;
    
    [player updateMeters];
    float audioPower = [player averagePowerForChannel:0];
    
#define min_interesting -40  // decibels
    float curLevel;
    if (nothingHappening)
        curLevel = min_interesting;
    else
        curLevel = audioPower;
    if (curLevel < min_interesting)
        curLevel = min_interesting;
    curLevel += -min_interesting;
    curLevel /= -min_interesting;
    
    [_sgView addPoint:curLevel];
    
    NSUInteger duration;
    if (nothingHappening)
        duration = [_audioPlayer duration] * 100.0;
    else if (_audioPlayer.isPlaying)
        duration = [_audioPlayer currentTime] * 100.0;
    else
        duration = [_audioRecorder currentTime] * 100.0;
    
    //GO - Adds 3 min limit for recording
    _recordingLength.text = [NSString stringWithFormat:@"%01d:%02d / 3:00",
                             (int)(duration / 6000),
                             (int)((duration % 6000) / 100)];
    if(duration > 6000 * 3)
    {
        [self stopRecording];
        _recordingLength.text = NSLocalizedString(@"Recording full", nil);
    }
    if (nothingHappening)
        [self stopTimer];
}

// Magic Tap
- (BOOL)accessibilityPerformMagicTap
{
    // Toggle recording
    [self recordAction:nil];
    
    return YES;
}

@end
