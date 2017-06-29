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
import Foundation


public typealias DTMFType = (Float, Float)
public typealias MarkSpaceType = (Float, Float)
open class DTMF
{
    open static let tone1     = DTMFType(1209.0, 697.0)
    open static let tone2     = DTMFType(1336.0, 697.0)
    open static let tone3     = DTMFType(1477.0, 697.0)
    open static let tone4     = DTMFType(1209.0, 770.0)
    open static let tone5     = DTMFType(1336.0, 770.0)
    open static let tone6     = DTMFType(1477.0, 770.0)
    open static let tone7     = DTMFType(1209.0, 852.0)
    open static let tone8     = DTMFType(1336.0, 852.0)
    open static let tone9     = DTMFType(1477.0, 852.0)
    open static let tone0     = DTMFType(1336.0, 941.0)
    open static let toneStar  = DTMFType(1209.0, 941.0)
    open static let tonePound = DTMFType(1477.0, 941.0)
    open static let toneA     = DTMFType(1633.0, 697.0)
    open static let toneB     = DTMFType(1633.0, 770.0)
    open static let toneC     = DTMFType(1633.0, 852.0)
    open static let toneD     = DTMFType(1633.0, 941.0)
    
    open static let standard      = MarkSpaceType(40.0, 40.0)
    open static let silentcircle  = MarkSpaceType(1000.0, 0.0)
    open static let motorola      = MarkSpaceType(250.0, 250.0)
    open static let whelen        = MarkSpaceType(40.0, 20.0)
    open static let fast          = MarkSpaceType(20.0, 20.0)
    
    /**
     Generates a series of Float samples representing a DTMF tone with a given mark and space.
     
     - parameter DTMF: takes a DTMFType comprised of two floats that represent the desired tone frequencies in Hz.
     - parameter markSpace: takes a MarkSpaceType comprised of two floats representing the duration of each in milliseconds. The mark represents the length of the tone and space the silence.
     - parameter sampleRate: the number of samples per second (Hz) desired.
     - returns: An array of Float that contains the Linear PCM samples that can be fed to AVAudio.
     */
    open static func generateDTMF(_ DTMF: DTMFType, markSpace: MarkSpaceType = motorola, sampleRate: Float = 44100.0) -> [Float]
    {
        let toneLengthInSamples = 10e-4 * markSpace.0 * sampleRate
        let silenceLengthInSamples = 10e-4 * markSpace.1 * sampleRate
        
        var sound = [Float](repeating: 0, count: Int(toneLengthInSamples + silenceLengthInSamples))
        let twoPI = 2.0 * Float(Double.pi)
        
        for i in 0 ..< Int(toneLengthInSamples) {
            
            // Add first tone at half volume
            let sample1 = 0.5 * sin(Float(i) * twoPI / (sampleRate / DTMF.0))
            
            // Add second tone at half volume
            let sample2 = 0.5 * sin(Float(i) * twoPI / (sampleRate / DTMF.1))
            
            sound[i] = sample1 + sample2
        }
        
        return sound
    }
}

extension DTMF
{
    enum characterForTone: Character {
        case tone1     = "1"
        case tone2     = "2"
        case tone3     = "3"
        case tone4     = "4"
        case tone5     = "5"
        case tone6     = "6"
        case tone7     = "7"
        case tone8     = "8"
        case tone9     = "9"
        case tone0     = "0"
        case toneA     = "A"
        case toneB     = "B"
        case toneC     = "C"
        case toneD     = "D"
        case toneStar  = "*"
        case tonePound = "#"
    }
    
    public static func toneForCharacter(_ character: Character) -> DTMFType?
    {
        var tone: DTMFType?
        switch (character) {
        case characterForTone.tone1.rawValue:
            tone = DTMF.tone1
            break
        case characterForTone.tone2.rawValue:
            tone = DTMF.tone2
            break
        case characterForTone.tone3.rawValue:
            tone = DTMF.tone3
            break
        case characterForTone.tone4.rawValue:
            tone = DTMF.tone4
            break
        case characterForTone.tone5.rawValue:
            tone = DTMF.tone5
            break
        case characterForTone.tone6.rawValue:
            tone = DTMF.tone6
            break
        case characterForTone.tone7.rawValue:
            tone = DTMF.tone7
            break
        case characterForTone.tone8.rawValue:
            tone = DTMF.tone8
            break
        case characterForTone.tone9.rawValue:
            tone = DTMF.tone9
            break
        case characterForTone.tone0.rawValue:
            tone = DTMF.tone0
            break
        case characterForTone.toneA.rawValue:
            tone = DTMF.toneA
            break
        case characterForTone.toneB.rawValue:
            tone = DTMF.toneB
            break
        case characterForTone.toneC.rawValue:
            tone = DTMF.toneC
            break
        case characterForTone.toneD.rawValue:
            tone = DTMF.toneD
            break
        case characterForTone.toneStar.rawValue:
            tone = DTMF.toneStar
            break
        case characterForTone.tonePound.rawValue:
            tone = DTMF.tonePound
            break
        default:
            break
        }
        
        return tone
    }
}
