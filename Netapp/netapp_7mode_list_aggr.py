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
cmd=NaElement("aggr-list-info")
output=s.invoke_elem(cmd)
if(output.results_errno() != 0):
    print("-E- COONECTION ERROR")
    sys.exit (1)
ret=output.child_get("aggregates")
for aggr in ret.children_get():
	aggr_name=aggr.child_get_string("name")
	aggr_used=aggr.child_get_int("size-used")/1024/1024/1024
	aggr_total=aggr.child_get_int("size-total")/1024/1024/1024
	aggr_free=aggr.child_get_int("size-available")/1024/1024/1024
	aggr_used_perc=aggr.child_get_int("size-percentage-used")
	print ("Name: %s " %aggr_name + "\t Total: %d" %(aggr_total) + "GB" + "\t Used: %d" %(aggr_used) + "GB" + "\t Avail: %d" %(aggr_free) + "GB" + "\t Percent: %d" %(aggr_used_perc) + "%")
