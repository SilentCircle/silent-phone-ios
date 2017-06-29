#!/usr/bin/python

import hashlib
import os 
import shutil
import subprocess
import sys


def usage():
    "The script's usage"
    thisScriptName = os.path.basename(__file__)
    print("Copy .mobileprovision files found in the sourceDir to the profileDir")
    print("renaming the file to its internal GUID name in the profileDir.")
    print("Only copy if the file is not already present in the toDir.")
    print("")
    print("Usage:")
    print("")
    print("   " + thisScriptName + " fromDir toDir")
    print("")
    print("Where:")
    print("   fromDir - Where the .mobileprovision files are copied from")
    print("   toDir   - Where the renamed files are copied to")
    exit()


def atStart():
    if len( sys.argv ) != 3:
        usage()

    dirFrom = testDir(sys.argv[1], "dirFrom")
    dirTo   = testDir(sys.argv[2], "dirTo")

    return dirFrom, dirTo


def testDir( path, name ):
    if not os.path.isdir(path):
        print "Invalid %s: %s" % (name, path)
        usage()
    return path


def error( message ):
    print "Error - %s" % message
    exit()


def scanDirTo( dirTo ):
    hashes = []
    filenames = []
    for file in os.listdir( dirTo ):
        if file.endswith(".mobileprovision"):
            with open(os.path.join(dirTo, file)) as f:
                hash = hashlib.sha1(f.read()).hexdigest()
                hashes.append( hash )
                filenames.append( file )
    return filenames, hashes


def getUUID( fromFile, dirTo ):
    cmd = '/usr/libexec/PlistBuddy -c \'print :UUID\' /dev/stdin <<< $(security cms -D -i "' + fromFile + '")'
    output = subprocess.check_output( cmd, shell=True ).strip()
    if len( output ) != 36:
        error( "File with no UUID, File: " + fromFile + " found >" + output + "<")
    else:
        file = output + ".mobileprovision"
        return file, os.path.join(dirTo, file)


def copyFiles(dirFrom, dirTo):
    dirToFiles, dirToHashes = scanDirTo(dirTo)
    for dirFromFile in os.listdir(dirFrom):
        if dirFromFile.endswith(".mobileprovision"):
            fromFilePath = os.path.join(dirFrom, dirFromFile)
            with open(fromFilePath) as f:
                fromFileHash = hashlib.sha1(f.read()).hexdigest()
                if fromFileHash not in dirToHashes:
                    toFile, toFilePath = getUUID(fromFilePath, dirTo)
                    if toFile in dirToFiles:
                        error("Filename with differnt contents in toDir %s and fromDir %s " % (toFile, dirFromFile))
                    else:
                        shutil.copy(fromFilePath, toFilePath)
                        print("copied: %s" % toFile)

                        
# main
# 
dirFrom, dirTo = atStart()
copyFiles( dirFrom, dirTo )

