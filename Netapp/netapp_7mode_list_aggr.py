#!/usr/bin/python
import sys
sys.path.append("/usr/lib/python2.6/site-packages/NetApp/")
from NaServer import *
from NaElement import *

def print_usage():
    print ("Usage: %s <filer> <user> <password> \n" %(sys.argv[0]))
    print ("<filer> -- Filer name\n")
    sys.exit (1)

args = len(sys.argv) - 1
if(args < 1):
   print_usage()

filer = sys.argv[1]
user = "ankor"
password = "ank0r!"

s = NaServer(filer, 1,0)
s.set_admin_user(user, password)
s.set_transport_type("HTTPS")
cmd=NaElement("aggr-list-info")
output=s.invoke_elem(cmd)
ret=output.child_get("aggregates")
for aggr in ret.children_get():
	#print ("Name: ", aggr.child_get_string("name")," Used: ", aggr.child_get_int("size-used")/1024/1024/1024," Total: ",aggr.child_get_int("size-total")/1024/1024/1024,"GB")
	aggr_name=aggr.child_get_string("name")
	aggr_used=aggr.child_get_int("size-used")/1024/1024/1024
	aggr_total=aggr.child_get_int("size-total")/1024/1024/1024
	aggr_used_perc=aggr.child_get_int("size-percentage-used")
	print ("Name: %s " %aggr_name + "\t Used: %d" %(aggr_used) + "GB" + "\t Total: %d" %(aggr_total) + "GB" + "\t Percent: %d" %(aggr_used_perc) + "%")
