#!/bin/bash


# Input: size string in form of: [0-9]T, [0-9]G, [0-9]M, [0-9]b, [0-9]
# Output: float number - size in G
getScaleInG()
{
        local property=$1
        if [ "${property//[0-9.]}X" = "TX" ]
        then
                property=$( echo "${property//[a-zA-Z]} * 1024"|bc -l )
        elif [ "${property//[0-9.]}X" = "GX" ]
        then
                property=${property//[a-zA-Z]}
        elif [ "${property//[0-9.]}X" = "MX" ]
        then
                property=$(echo "${property//[a-zA-Z]} / 1024"|bc -l )
        elif [ "${property//[0-9.]}X" = "KX" ]
        then
                property=$(echo "${property//[a-zA-Z]} / 1048576"|bc -l)
        elif [ "${property//[0-9.]}X" = "bX" ]
        then
                property=0
	else
		property=0
        fi
        echo $property
}
