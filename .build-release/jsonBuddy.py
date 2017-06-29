#!/usr/bin/python
import sys
import json

def usage():
    print("Usage %s json-file read  key" % sys.argv[0])
    print("Usage %s json-file write key value" % sys.argv[0])
    exit(1)

if len(sys.argv) < 4:
    usage()

file    = str(sys.argv[1])
command = str(sys.argv[2]).strip().lower()
key     = str(sys.argv[3])
data    = {}

if not ( ( command == "read"  and len(sys.argv) == 4 )
   or    ( command == "write" and len(sys.argv) == 5 ) ):
    usage()

try:
    json_data = open( file )
except:
    if command == "read":
        print("Unable to open file %s" % file)
        usage()
else:
    data = json.load(json_data)


if command == "read":
    print("{}".format(data[key]))
else:  # write
    data[ key ] = str(sys.argv[4])

    with open(file, 'w') as outfile:
        json.dump(data, outfile, indent=4, sort_keys=True)
