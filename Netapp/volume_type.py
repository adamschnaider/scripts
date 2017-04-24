#!/usr/bin/python
import sys
sys.path.append("/usr/lib/python2.6/site-packages/NetApp/")
from NaServer import *
from NaElement import *

def print_usage():
    print ("Usage: hello_ontapi.py <filer> <user> <password> \n")
    print ("<filer> -- Filer name\n")
    print ("<user> -- User name\n")
    print ("<password> -- Password\n")
    sys.exit (1)

args = len(sys.argv) - 1
if(args < 3):
   print_usage()

filer = sys.argv[1]
user = sys.argv[2]
password = "ank0r!"
volume = sys.argv[3]

s = NaServer(filer, 1,0)
s.set_admin_user(user, password)
s.set_transport_type("HTTPS")
cmd=NaElement("volume-options-list-info")
cmd.child_add_string("volume",volume)
output=s.invoke_elem(cmd)
if(output.results_errno() != 0):
    sys.exit (1)

ret=output.child_get("options")
for option in ret.children_get():
    if(option.child_get_string("name") == "actual_guarantee"):
        if(option.child_get_string("value") == "volume"):
    		regular=1
        else : 
            if(option.child_get_string("value") == "partial"):
                sys.exit (2)
    if(option.child_get_string("value") == "snapmirrored"):
        if(option.child_get_string("value") == "on"):
            sys.exit (3)

sys.exit (0)
