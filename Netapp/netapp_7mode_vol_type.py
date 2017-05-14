#!/usr/bin/python
import sys
sys.path.append("/usr/lib/python2.6/site-packages/NetApp/")
from NaServer import *
from NaElement import *

def print_usage():
    print ("Usage: %s <filer> <volume>\n" %(sys.argv[0]))
    sys.exit (1)

args = len(sys.argv) - 1
if(args < 2):
   print_usage()

filer = sys.argv[1]
volume = sys.argv[2]

s = NaServer(filer, 1,0)
s.set_transport_type("HTTPS")
cmd=NaElement("volume-options-list-info")
cmd.child_add_string("volume",volume)
output=s.invoke_elem(cmd)
if(output.results_errno() != 0):
    sys.exit (1)

ret=output.child_get("options")
regular=0
for option in ret.children_get():
    if(option.child_get_string("name") == "actual_guarantee"):
        if(option.child_get_string("value") == "volume"):
    		regular=1
        else : 
            if(option.child_get_string("value") == "partial"):
                print ("flexcache")
                sys.exit (2)
    if(option.child_get_string("name") == "snapmirrored"):
        if(option.child_get_string("value") == "on"):
            print ("snapmirrored")
            sys.exit (3)

if(regular == 1):
    print ("volume")
    sys.exit (0)
else :
    sys.exit (1)
