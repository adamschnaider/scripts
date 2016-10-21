#!/bin/bash

. /root/scripts/functions/NetappHandler.bash

echo "HI"
#time (netapp_vfiler_check	mtlfs01 && vfiler=$filer)
#time netapp_7mode_vol_resize	mtlfs01	vol1
#netapp_7mode_vol_resize	mtlfs03	adams_test +1G
#netapp_7mode_vol_resize	mtlfs03	adams_test
#netapp_7mode_vol_resize		usicslabfs01	local
#netapp_7mode_vol_resize		mtdkfs01	servers_BU
#netapp_7mode_vol_resize		labfs01	mswg
#netapp_7mode_vol_resize		manasfs2 vol8
#netapp_7mode_vol_resize		mtxfs01 mtx_esx_ds_01
#netapp_7mode_vol_resize 	mtvfs02 Vmware_Datastore_MTV_01 +50G
#netapp_7mode_vol_resize	mtdkfs01	mtdk_share
#netapp_7mode_vol_resize		labfs02	LIT
netapp_7mode_vol_resize		$1	$2	$3
