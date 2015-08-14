
# LOAD
# ---------------------------------------------------------------------------------

wps_load() { 

	export PROXY_IP="`awk 'NR==1 {print $1}' /etc/hosts`"

	find $run -type f -exec chmod +x {} \;
	conf="/etc/nginx/conf.d"
	rm -rf ${conf}/*

	cd /tmp
	
	echo "" > events.json
	echo "" > domains.json
	
	docker="curl -sN --unix-socket docker.sock -X GET http:"
	containers="`$docker/containers/json | jq -r '.[].Id'`"
	
	for id in $containers; do

		domain="`$docker/containers/$id/json | jq -r '.Config.Env[]?' | grep WP_DOMAIN | cut -d= -f2`"
		name="`$docker/containers/$id/json | jq -r '.Name' | sed 's|/||g'`"
		ssl="`$docker/containers/$id/json | jq -r '.Config.Env[]?' | grep WP_SSL | cut -d= -f2`"
		ip="`$docker/containers/$id/json | jq -r '.NetworkSettings.IPAddress'`"

		if [[  ! -z $domain  ]]; 
		then echo -e "{\"domain\":\"$domain\",\"ip\":\"$ip\",\"ssl\":\"$ssl\",\"name\":\"$name\"}" >> domains.json
		fi

	done && unset domain
	
	domains="`cat domains.json | jq -r '.domain' | awk '!a[$0]++'`"

	for domain in $domains; do
	
		vhost="${conf}/${domain}"
		servers="`jq -r '. | select(.domain == "'$domain'") | .ip' < domains.json`"
		ssl="`jq -r '. | select(.domain == "'$domain'") | .ssl' < domains.json | awk '!a[$0]++'`"

		if [[  $ssl == 'true'  ]];
		then port='443' && while [[  ! -f /wps/ssl/${domain}.crt  ]]; do sleep 1; done
		else port='80'
		fi
	
		echo -e "upstream $domain {" > $vhost
		for server in $servers; do
# 			name="`jq -r '. | select(.ip == "'$server'") | .name' < domains.json`"
			echo -e "	server $server:$port;" >> $vhost
		done
		echo -e "}\n" >> $vhost
				
		if [[  $ssl == 'true'  ]];
		then cat $etc/proxy443.conf | sed "s|DOMAIN|$domain|g" >> $vhost
		else cat $etc/proxy80.conf  | sed "s|DOMAIN|$domain|g" >> $vhost
		fi
		
	done
}
