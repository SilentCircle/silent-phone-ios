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
//
//  DTMFPlayer.swift
//  SPi3
//
//  Created by Stelios Petrakis on 24/05/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

import AVFoundation

@objc class DTMFPlayer: NSObject {
    
    let engine: AVAudioEngine               = AVAudioEngine()
    var player: AVAudioPlayerNode           = AVAudioPlayerNode()
    var sampleRate: Float                   = 8000.0
    var buffers: [String:AVAudioPCMBuffer]  = [String:AVAudioPCMBuffer]()
    var audioFormat: AVAudioFormat
    
    fileprivate override init () {
        
        self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: Double(self.sampleRate),
                                         channels: 2,
                                         interleaved: false)

        super.init()
        
        self.engine.attach(self.player)
        
        self.engine.connect(self.player,
                            to:self.engine.mainMixerNode,
                            format:self.audioFormat)

        do {
            try self.engine.start()
        } catch let error as NSError {
            print("Engine start failed - \(error)")
        }

        changePlayerVolume()
        
        // Generate buffers
        for character in "0123456789*#".characters {
            if let tone = DTMF.toneForCharacter(character) {

                let samples = DTMF.generateDTMF(tone,
                                                markSpace: DTMF.silentcircle,
                                                sampleRate: sampleRate)
                let frameCount = AVAudioFrameCount(samples.count)
                let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                              frameCapacity: frameCount)
                
                buffer.frameLength = frameCount
                let channelMemory = buffer.floatChannelData
                for channelIndex in 0 ..< Int(audioFormat.channelCount) {
                    let frameMemory = channelMemory![channelIndex]
                    memcpy(frameMemory, samples, Int(frameCount) * MemoryLayout<Float>.size)
                }

                self.buffers[String(character)] = buffer
            }
        }
    }
    
    fileprivate func changePlayerVolume() {
        
        var volume:Double = 1.0
        
        if AVAudioSession.sharedInstance().category == AVAudioSessionCategorySoloAmbient {
        
            let systemVolume:Double = Double(AVAudioSession.sharedInstance().outputVolume)
        
            volume = max(0.01, 1.0 - systemVolume)
        }

        self.player.volume = Float(volume)
    }
    
    func play(_ phoneNumber: String) {

        if(phoneNumber.characters.count == 0) {
            return
        }
        
        if(DTMF.toneForCharacter(phoneNumber.characters.first!) == nil) {
            
            return
        }
        
        if(!self.engine.isRunning) {
            
            do {
                try self.engine.start()
            } catch let error as NSError {
                print("Engine start failed - \(error)")
            }
        }
        
        changePlayerVolume()
        
        self.player.scheduleBuffer(self.buffers[phoneNumber]!,
                                   at:nil,
                                   options:.interrupts,
                                   completionHandler:nil)
        
        self.player.play()
    }
    
    func pause() {
        
        self.player.pause()
    }
    
    func reset() {
        
        stop()
        
        self.engine.reset()
    }
    
    func stop() {
        
        self.player.stop()
        self.engine.stop()
    }
}
