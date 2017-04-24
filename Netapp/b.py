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

if(args < 4):

   print_usage()

filer = sys.argv[1]

user = sys.argv[2]

password = sys.argv[3]

volume = sys.argv[4]

s = NaServer(filer, 1, 6)

s.set_server_type("Filer")

s.set_admin_user(user, password)

s.set_transport_type("HTTPS")

output = s.invoke("system-get-version")

if(output.results_errno() != 0):

   r = output.results_reason()

   print("Failed: \n" + str(r))

else :

   r = output.child_get_string("version")

   print (r + "\n")

cmd = NaElement("volume-list-info")

cmd1 = NaElement("snapshot-list-info")

ret = s.invoke_elem(cmd)

ret1 = s.invoke_elem(cmd1)

volumes = ret.child_get("volumes")

snaps = ret1.child_get("snapshots")

for vol in volumes.children_get():

        print(vol.child_get_string("name"))

        print(vol.child_get_int("size-total"))

        print(vol.child_get_string("mirror-status"))

        print(vol.child_get_int("snapshot-percent-reserved"))

#        for snap in snaps.children_get(volume=vol.child_get_string("name")):

#                print(snap.child_get_string("name"))

