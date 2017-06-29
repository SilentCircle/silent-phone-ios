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
#!/usr/bin/env xcrun --sdk macosx swift

import Foundation

//MARK: BASH / SHELL
//http://stackoverflow.com/questions/26971240/how-do-i-run-an-terminal-command-in-a-swift-script-e-g-xcodebuild
func shell(launchPath: String, arguments: [String]) -> String
{
    let task = Process()
    task.launchPath = launchPath
    task.arguments = arguments
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: String.Encoding.utf8)!
    if output.characters.count > 0 {
        //remove newline character.
        let lastIndex = output.index(before: output.endIndex)
        return output[output.startIndex ..< lastIndex]
    }
    return output
}

func bash(command: String, arguments: [String]) -> String {
    let whichPathForCommand = shell(launchPath: "/bin/bash", arguments: [ "-l", "-c", "which \(command)" ])
    return shell(launchPath: whichPathForCommand, arguments: arguments)
}


//MARK: - Git
func parseSubmodules(subs: String) -> [[String:String]] {
    var submods = [[String:String]]()
    
    // split subs chunk into lines
    let lines = subs.components(separatedBy: "\n")
    
    for line in lines {
        
        // split lines on spaces:
        // N.B. observed output: 
        // ' '1a856111addabdbd2831c3fa34d3c5dba884edeb libs/libzina (spi/v3.3.6-91-g1a85611)
        // OR
        // +8436fddd9422c4c64371c15b238b4e54fb07258b libs/libzina (spi/v3.3.6-93-g8436fdd)
        // i.e. 3 OR 4 parts
        let parts = line.components(separatedBy: " ")
        let first_char = String(line.characters.prefix(1))
        let hasLeadingSpace = (first_char == " ")

        // 4 parts with leading space, otherwise 3
        let hash    = (hasLeadingSpace) ? parts[1] : parts[0]
        // if 1st char not space, prefix branch with char+space
        let branch  = (hasLeadingSpace) ? parts[2] : first_char + " " + parts[1]
        let details = (hasLeadingSpace) ? parts[3] : parts[2]
        
        // derive submod_short_hash from submod_hash.         
        // if first char on hash strings is not a space, 
        // take an additional substring char. 
        let endIdx = hash.index(hash.startIndex, offsetBy: (hasLeadingSpace) ? 8 : 9)
        let short_hash = hash.substring(to: endIdx)
        
        // derive submod_short_branch by stripping 'libs/'[branch],
        // e.g.: 'libzina' OR '+ libzina'  
        var short_branch = branch.components(separatedBy: "/")[1]
        short_branch = (hasLeadingSpace) ? short_branch : first_char + " " + short_branch
        
        // add key=val dictionaries to submods array for each submodule
        submods.append(["submod_hash":hash,
                        "submod_branch":branch,
                        "submod_branch_details":details,
                        "submod_short_hash":short_hash,
                        "submod_short_branch":short_branch])
    }
    
    return submods
}

func getCurrentBranch() -> String {
    let branches = bash(command: "git", arguments: ["branch"])
    let lines  = branches.components(separatedBy: "\n") as [String]
    let filtered = lines.filter {
        let idx = $0.index($0.startIndex, offsetBy: 1)
        return $0.substring(to: idx) == "*"
    }
    guard let filter = filtered.first else {
        return "N/A"
    }
    let idx = filter.index(filter.startIndex, offsetBy: 1)
    let branch = filter.substring(from: idx)
    
    return branch
}

//let current_branch = bash(command: "git", arguments: ["describe", "--contains", "--all", "HEAD"])
//let current_branch = bash(command: "git", arguments: ["branch", "|", "grep", "\*", "|", "cut -d", "' '", "-f2"])
let current_branch = getCurrentBranch() 
print("current_branch: \(current_branch)")

let current_branch_count = bash(command: "git", arguments: ["rev-list", "--count", "HEAD"])
print("v3.3.6 (\(current_branch_count))")

let current_hash   = bash(command: "git", arguments: ["rev-parse", "HEAD"])
let current_short_hash = bash(command: "git", arguments: ["rev-parse", "--short", "HEAD"])
print("\(current_branch) \(current_short_hash)")

let submods_chunk = bash(command: "git", arguments: ["submodule", "status"]) 
let submodules_info = parseSubmodules(subs: submods_chunk)


//MARK: - Packaging data
let infoDict:[String:Any] = ["current_branch": current_branch,
                             "current_branch_count": current_branch_count,
                             "current_hash": current_hash,
                             "current_short_hash": current_short_hash,
                             "submodules": submodules_info]


//MARK: - File handling
let fileManager = FileManager.default
let curr_dir = fileManager.currentDirectoryPath
print("curr_dir: \(curr_dir)")
 
var fileURL = URL(fileURLWithPath: curr_dir).appendingPathComponent("BuildInfo.plist")
print("fileURL: \(fileURL)")
  
// write plist
do {  
    let data = try PropertyListSerialization.data(fromPropertyList: infoDict, format: .xml, options: 0)
    try data.write(to: fileURL, options: .atomic) 
} catch {  
    print(error.localizedDescription)
    exit(1)
}

exit(0)
