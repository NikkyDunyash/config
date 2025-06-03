#!/bin/bash
# shell script to replace i3status

readonly DEF_FG_CL="#ffffff"

readonly BAD_CL="#ff0000"
readonly OK_CL="#ffffff"
readonly GOOD_CL="#00ff00"


function json_obj()
{
	local full_text=$1
	local color=$2
	local short_text=$3
	if [ -z $color ]; then
	   color=$DEF_FG_CL
	fi
	echo "{\"full_text\":\"${full_text}\", \"color\":\"${color}\", \
		   \"short_text\":\"${short_text}\",  \
		   \"separator\": false, \"separator_block_width\": 25}"
}

function time_json()
{
	echo "$(json_obj "$(date "+%T %Z")")"
}

function date_json()
{
	echo "$(json_obj "󰸗 $(date "+%a %d/%m/%Y")")"
}

function battery_json()
{
	sym=""
	color=""
	cap=$(cat /sys/class/power_supply/BAT0/capacity)
	stat=$(cat /sys/class/power_supply/BAT0/status)
	declare -a bat_syms=("󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" "󰂄")
	sym=${bat_syms[(( $cap/10-1 ))]}
	if [ $stat = "Charging" ] || [ $stat = "Full" ]; then
		sym=${bat_syms[10]}
		color=$GOOD_CL
	elif (( $cap <= 20 )); then
		color=$BAD_CL
	elif (( $cap < 80)); then
		color=$OK_CL
	else 
		color=$GOOD_CL
	fi
	
	echo "$(json_obj "${sym} ${cap}%" "${color}")"
}

function ds_json()
{
    res=''
    sym=" "
    color='#ffffff'
    ds_paths=(/sys/class/power_supply/ps-controller-battery-*)
    
    if echo $ds_paths | grep -q '*' ; then
        return 1
    fi

    for p in ${ds_paths[@]}; do
        stat=$(cat $p/status)
        cap=$(cat $p/capacity)
        if [ $stat = 'Charging' ] || [ $stat = 'Full' ]; then
            color=$GOOD_CL
        else
            color='#'
            color_array=()
            brightness=0
            rgb=('red' 'green' 'blue')
            for i in ${!rgb[@]}; do
                c_brightness=$(cat $p/device/leds/*${rgb[$i]}/brightness)
                color_array[$i]=$c_brightness
                let brightness+=color_array[$i]
            done
            for i in ${!color_array[@]}; do
                color+=$(printf '%02x' $(printf '%.0f'\
                    $(echo "${color_array[${i}]} * 255 / ${brightness}" | bc -l)))
            done
        fi
        res+="$(json_obj "${sym} ${cap}%" "${color}"), "
    done
    echo $res
}

function mem_json()
{
	let i=0
	while read -d $'\n'  line || [[ -n $line ]]; do
	    mem_info[$i]=$line
		let i++
	done <<< "$(free -h)"
	read row_name total used free shared cache avail <<< ${mem_info[1]}
	echo "$(json_obj "  ${used}/${total}")"
}

function disk_json()
{
	while read -d $'\n'  line || [[ -n $line ]]; do
	    disk_info=$line
		read fs size used avail use mount <<< ${disk_info}
		if [ $mount = "/" ]; then
			echo "$(json_obj "  ${used}/${size}")"
			break
		fi 
	done <<< "$(df -h)"
}
    

# Send the header so that i3bar knows we want to use JSON:
echo '{ "version": 1 }'
# Begin the endless array.
echo '['
# Send an empty first array of blocks to make the loop simpler:
echo '[]'

while true :
do
    echo ",[$(ds_json) $(battery_json), $(mem_json), $(disk_json), \
		  $(time_json), $(date_json)]" \
		|| exit 1
	sleep 1
done
