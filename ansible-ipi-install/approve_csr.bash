#!/bin/bash

if [ $# -ne 1 ]
then
        echo "There should be one arg: the number of workers expected."
        exit 1
fi

until [ $(oc get nodes | grep "\bReady\s*worker" | wc -l) == $1 ]
do
        oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
        sleep 5
done
