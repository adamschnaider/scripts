#!/usr/bin/python
import sys
from subprocess import call
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
cmd1=NaElement("volume-list-info")
ret1=s.invoke_elem(cmd1)
if(ret1.results_errno() != 0):
    print("-E- CONNECTION ERROR")
    sys.exit (1)
output1=ret1.child_get("volumes")
for option in output1.children_get():
	vol_name=option.child_get_string("name")
	vol_state=option.child_get_string("state")
	vol_id=option.child_get_string("uuid")
	vol_total=option.child_get_int("size-total")
	vol_used=option.child_get_int("size-used")
	if (vol_state == "online"):
		vol_percent_used=int(round((float(vol_used)/float(vol_total))*100))
	else:
		vol_percent_used=0
	cmd2=NaElement("volume-options-list-info")
	cmd2.child_add_string("volume",vol_name)
	output2=s.invoke_elem(cmd2)
	ret2=output2.child_get("options")
	regular=0
	for option2 in ret2.children_get():
		if(option2.child_get_string("name") == "actual_guarantee"):
			if(option2.child_get_string("value") == "volume"):
				regular=1
			else :
				if(option2.child_get_string("value") == "partial"):
					vol_type="flexcache"
		if(option2.child_get_string("name") == "snapmirrored"):
			if(option2.child_get_string("value") == "on"):
				vol_type="snapmirrored"
	if(regular == 1):
		vol_type="volume"
	print(vol_name + " " + vol_state + " " + vol_type + " " + vol_id + " " + str(vol_percent_used))
