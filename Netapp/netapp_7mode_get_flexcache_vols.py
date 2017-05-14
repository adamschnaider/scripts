#!/usr/bin/python
import sys
sys.path.append("/usr/lib/python2.6/site-packages/NetApp/")
from NaServer import *
from NaElement import *

def print_usage():
    print ("Usage: %s <filer>\n" %(sys.argv[0]))
    sys.exit (1)

args = len(sys.argv) - 1
if(args < 1):
   print_usage()

filer = sys.argv[1]

s = NaServer(filer, 1,0)
s.set_transport_type("HTTPS")
cmd=NaElement("volume-list-info")
ret=s.invoke_elem(cmd)
output=ret.child_get("volumes")
for option in output.children_get():
	if(option.child_get_string("space-reserve") == "partial"):
		print("Flexcache volume: " + option.child_get_string("name") + "\tFlexcache source: " + option.child_get_string("remote-location"))
