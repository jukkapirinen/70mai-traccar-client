#!/bin/sh

gps_dir=/mnt/other/4g_gps
start_script=$( date )
log_file=/mnt/sd/timechecker.log

set_time_gps_dir(){
         
        lsout1=$(ls ${gps_dir} -Artl | tail -1)
	first_size=$(echo ${lsout1} | awk '{print $5}')
	first_file=$(echo ${lsout1} | awk '{print $9}')
	sleep 5s
	
	lsout2=$(ls ${gps_dir} -Artl | tail -1)
        second_size=$(echo ${lsout2} | awk '{print $5}')    
        second_file=$(echo ${lsout2} | awk '{print $9}') 

	if ( [ -z "$second_file" ] || [ "$first_size" -eq "$second_size" ] ); then
		echo $start_script" ERROR: No GPS signal." >> $log_file   
		exit
	fi
	last_mark=$( tail -n 1 ${gps_dir}"/"${second_file} )                          
        epoch=$(echo ${last_mark} | cut -d',' -f 1)                    
        n=`expr "$epoch" : '.*'`                                       
        if ! ( [ "$n" -eq "10" ] ); then                               
            echo $start_script" ERROR: Wrong epoch time in GPS data file "$last_mark >> $log_file                     
            exit                                                         
        fi                                                               

        gps_year=`awk -v a=$epoch 'BEGIN { print strftime("%Y", a ); }'`
        gps_month=`awk -v a=$epoch 'BEGIN { print strftime("%m", a ); }'`
        gps_day=`awk -v a=$epoch 'BEGIN { print strftime("%d", a ); }'`  
        gps_hour=`awk -v a=$epoch 'BEGIN { print strftime("%H", a ); }'` 
        gps_minute=`awk -v a=$epoch 'BEGIN { print strftime("%M", a ); }'`
        gps_sec=`awk -v a=$epoch 'BEGIN { print strftime("%S", a ); }'`   
                      
	epoch=`date +%s`                                                                      
        reg_year=`awk -v a=$epoch 'BEGIN { print strftime("%Y", a ); }'`                      
        reg_month=`awk -v a=$epoch 'BEGIN { print strftime("%m", a ); }'`                     
        reg_day=`awk -v a=$epoch 'BEGIN { print strftime("%d", a ); }'`                       
        reg_hour=`awk -v a=$epoch 'BEGIN { print strftime("%H", a ); }'`                      
        reg_minute=`awk -v a=$epoch 'BEGIN { print strftime("%M", a ); }'`                    
        reg_sec=`awk -v a=$epoch 'BEGIN { print strftime("%S", a ); }'`                       
                                                                                              
	if ( [ "$gps_year" -eq "$reg_year" ] && [ "$gps_month" -eq "$reg_month" ] && [ "$gps_day" -eq "$reg_day" ] && [ "$reg_minute" -ge 5 ]&& [ "$reg_minute" -le 55 ] ); then
                new_date=$reg_year"-"$reg_month"-"$reg_day" "$reg_hour":"$gps_minute":"$gps_sec                                                     
                start_script=$( date )
				date "${new_date}"                                                                                                                  
                hwclock -u -w                                                                                                                       
				echo $start_script" INFO: Sync time with GPS to "$new_date >> $log_file
		return                                                                                                                               
        fi                                                                                                                                          

		echo $start_script" ERROR: Time window is not acceptable to change. REG time "$reg_year"-"$reg_month"-"$reg_day" "$reg_hour":"$reg_minute":"$reg_sec" GPS time "$gps_year"-"$gps_month"-"$gps_day" "$gps_hour":"$gps_minute":"$gps_sec >> $log_file                                                                                                                         
return

}



set_time_4g(){

stty -F /dev/ttyUSB5 cs8 -cstopb -parenb litout -crtscts -echo -raw
exec 3</dev/ttyUSB5
  cat <&3 > /tmp/ttyDump.dat &
  PID=$!
    echo "AT+CTZU=3" > /dev/ttyUSB5
    echo "AT+CCLK?" > /dev/ttyUSB5
    sleep 0.5s
  kill $PID
  wait $PID 2>/dev/null

exec 3<&-

modem_date=$(cat /tmp/ttyDump.dat |grep -Eo '\"(.*)\"')
n=`expr "$modem_date" : '.*'`
if [ "$n" -ne "22" ]; then
    echo $start_script" ERROR: Wrong answer from 4G HW kit. "$modem_date >> $log_file
    exit
fi
modem_year=`echo $modem_date | cut -c 2-3`

if [ "$modem_year" -eq "00" ]; then  #change to eq
        echo $start_script" ERROR: Wrong date from cell network or no mobile signal "$modem_date >> $log_file
    exit
fi

modem_month=`echo $modem_date | cut -c 5-6`
modem_day=`echo $modem_date | cut -c 8-9`
modem_hour=`echo $modem_date | cut -c 11-12`
modem_minutes=`echo $modem_date | cut -c 14-15`
modem_seconds=`echo $modem_date | cut -c 17-18`
new_date="20"$modem_year"-"$modem_month"-"$modem_day" "$modem_hour":"$modem_minutes":"$modem_seconds
date "${new_date}"
hwclock -u -w

echo $start_script" INFO: Sync time with 4G HW kit to "$new_date >> $log_file

return
}



if [ -c /dev/ttyUSB5 ]; then
	set_time_4g
	exit
fi

if [ -f $data_file ]; then  
	set_time_gps_dir
	exit
fi

echo $start_script" ERROR: 4G HW kit and GPS data not found." >> $log_file
