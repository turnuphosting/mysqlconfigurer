#!/bin/bash
# install.sh - Version 0.9.0
# (C) Releem, Inc 2022
# All rights reserved

# Variables
MYSQLCONFIGURER_PATH="/tmp/.mysqlconfigurer/"
RELEEM_CONF_FILE="/opt/releem/releem.conf"
MYSQLTUNER_FILENAME=$MYSQLCONFIGURER_PATH"mysqltuner.pl"
MYSQLTUNER_REPORT=$MYSQLCONFIGURER_PATH"mysqltunerreport.json"
MYSQLCONFIGURER_CONFIGFILE=$MYSQLCONFIGURER_PATH"z_aiops_mysql.cnf"
MYSQL_MEMORY_LIMIT=0

function wait_restart() {
  sleep 1
  flag=0
  spin[0]="-"
  spin[1]="\\"
  spin[2]="|"
  spin[3]="/"
#  echo -n "Waiting for restarted mysql ${spin[0]}"
  printf "\033[34m\n* Waiting for mysql service to start 120 seconds ${spin[0]}"

  while !(mysqladmin ping > /dev/null 2>&1)
  do
    flag=$(($flag + 1))
    if [ $flag == 120 ]; then
#        echo "$flag break"
        break
    fi
    i=`expr $flag % 4`
    #echo -ne "\b${spin[$i]}"
    printf "\b${spin[$i]}"
    sleep 1
  done
  printf "\033[0m\n"
}
function releem_rollback_config() {
    printf "\033[31m\n* Rolling back MySQL configuration!\033[0m\n"
    if [ -z "$RELEEM_MYSQL_CONFIG_DIR" ]; then
        printf "\033[34m\n* MySQL configuration directory is not found.\033[0m"
        printf "\033[34m\n* Try to reinstall Releem Agent, and please set the my.cnf location.\033[0m"
        exit 1;
    fi
    if [ -z "$RELEEM_MYSQL_RESTART_SERVICE" ]; then
        printf "\033[34m\n* The command to restart the MySQL service was not found. Try to reinstall Releem Agent.\033[0m"
        exit 1;
    fi




    FLAG_RESTART_SERVICE=1
    if [ -z "$RELEEM_RESTART_SERVICE" ]; then
    	read -p "Please confirm roll back MySQL configuration? (Y/N) " -n 1 -r
	echo    # move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
	    printf "\033[34m\n* A confirmation to restart the service has not been received. Releem recommended configuration has not been applied.\033[0m\n"
	    FLAG_RESTART_SERVICE=0
        fi
    elif [ "$RELEEM_RESTART_SERVICE" -eq 0 ]; then
        FLAG_RESTART_SERVICE=0
    fi
    if [ "$FLAG_RESTART_SERVICE" -eq 0 ]; then
        exit 1
    fi        

    printf "\033[31m\n* Deleting a configuration file... \033[0m\n"
    rm -rf $RELEEM_MYSQL_CONFIG_DIR/*
    echo "----Test config-------"

    printf "\033[31m\n* Restarting with command '$RELEEM_MYSQL_RESTART_SERVICE'...\033[0m\n"
    eval "$RELEEM_MYSQL_RESTART_SERVICE" &
    wait_restart
    if [[ $(mysqladmin ping 2>/dev/null) == "mysqld is alive" ]];
    then
        printf "\033[32m\n* MySQL service started successfully!\033[0m\n"
    else
        printf "\033[31m\n* Failed to roll back MySQL configuration! Check mysql error log! \033[0m\n"
    fi
}

function releem_apply_config() {
    printf "\033[34m\n* Applying recommended MySQL configuration...\033[0m\n"
    if [ ! -f $MYSQLCONFIGURER_CONFIGFILE ]; then
        printf "\033[34m\n* Recommended MySQL configuration is not found.\033[0m"
        printf "\033[34m\n* Please apply recommended configuration later or run Releem Agent manually:\033[0m"
        printf "\033[32m\n bash /opt/releem/mysqlconfigurer.sh \033[0m\n\n"
        exit 1;
    fi
    if [ -z "$RELEEM_MYSQL_CONFIG_DIR" ]; then
        printf "\033[34m\n* MySQL configuration directory is not found.\033[0m"
        printf "\033[34m\n* Try to reinstall Releem Agent, and please set the my.cnf location.\033[0m"
        exit 1;
    fi
    if [ -z "$RELEEM_MYSQL_RESTART_SERVICE" ]; then
        printf "\033[34m\n* The command to restart the MySQL service was not found. Try to reinstall Releem Agent.\033[0m"
        exit 1;
    fi
    printf "\033[34m\n* Copy file $MYSQLCONFIGURER_CONFIGFILE to directory $RELEEM_MYSQL_CONFIG_DIR/...\033[0m\n"
    yes | cp -fr $MYSQLCONFIGURER_CONFIGFILE $RELEEM_MYSQL_CONFIG_DIR/

    echo "----Test config-------"

    FLAG_RESTART_SERVICE=1
    if [ -z "$RELEEM_RESTART_SERVICE" ]; then
    	read -p "Please confirm roll back MySQL configuration? (Y/N) " -n 1 -r
	echo    # move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
	    printf "\033[34m\n* A confirmation to restart the service has not been received. Releem recommended configuration has not been applied.\033[0m\n"
	    FLAG_RESTART_SERVICE=0
        fi
    elif [ "$RELEEM_RESTART_SERVICE" -eq 0 ]; then
        FLAG_RESTART_SERVICE=0
    fi
    if [ "$FLAG_RESTART_SERVICE" -eq 0 ]; then
        exit 1
    fi        


    printf "\033[34m\n* Restarting with command '$RELEEM_MYSQL_RESTART_SERVICE'...\033[0m\n"
    eval "$RELEEM_MYSQL_RESTART_SERVICE" &
    wait_restart



    if [[ $(mysqladmin ping 2>/dev/null) == "mysqld is alive" ]];
    then
        printf "\033[32m\n* MySQL service started successfully!\033[0m\n"
    else
        printf "\033[31m\n* MySQL service doesn't start! Check the MySQL error log! \033[0m\n"
        printf "\033[31m\n* Try to roll back the configuration application using the command: \033[0m\n"
        printf "\033[32m\n bash /opt/releem/mysqlconfigurer.sh -r\033[0m\n\n"
    fi
    exit 0
}


if test -f $RELEEM_CONF_FILE ; then
    . $RELEEM_CONF_FILE

    RELEEM_API_KEY=$apikey
    if [ ! -z $memory_limit ]; then
        MYSQL_MEMORY_LIMIT=$memory_limit
    fi
    if [ ! -z $mysql_cnf_dir ]; then
        RELEEM_MYSQL_CONFIG_DIR=$mysql_cnf_dir
    fi
    if [ ! -z "$mysql_restart_service" ]; then
        RELEEM_MYSQL_RESTART_SERVICE=$mysql_restart_service
    fi
fi

# Parse parameters
while getopts "k:m:ar" option
do
case "${option}"
in
k) RELEEM_API_KEY=${OPTARG};;
m) MYSQL_MEMORY_LIMIT=${OPTARG};;
a) releem_apply_config;;  ###RELEEM_APPLY_CONFIG=1;;
r) releem_rollback_config;;
esac
done

echo -e "\033[34m\n* Checking the environment...\033[0m"

# Check RELEEM_API_KEY is not empty
if [ -z "$RELEEM_API_KEY" ]; then
    echo >&2 "RELEEM_API_KEY is empty please sign up at https://releem.com/appsignup to get your Releem API key. Aborting."
    exit 1;
fi

command -v curl >/dev/null 2>&1 || { echo >&2 "Curl is not installed. Please install Curl. Aborting."; exit 1; }
command -v perl >/dev/null 2>&1 || { echo >&2 "Perl is not installed. Please install Perl. Aborting."; exit 1; }
perl -e "use JSON;" >/dev/null 2>&1 || { echo >&2 "Perl module JSON is not installed. Please install Perl module JSON. Aborting."; exit 1; }

# Check if the tmp folder exists
if [ -d "$MYSQLCONFIGURER_PATH" ]; then
    # Clear tmp directory
    rm $MYSQLCONFIGURER_PATH/*
else
    # Create tmp directory
    mkdir $MYSQLCONFIGURER_PATH
fi

# Check if MySQLTuner already downloaded and download if it doesn't exist
if [ ! -f "$MYSQLTUNER_FILENAME" ]; then
    # Download latest version of the MySQLTuner
    curl -s -o $MYSQLTUNER_FILENAME -L https://raw.githubusercontent.com/major/MySQLTuner-perl/07cfdafaa7dee483fd715c88048b4fa19f3f3df3/mysqltuner.pl
fi

echo -e "\033[34m\n* Collecting metrics...\033[0m"

# Collect MySQL metrics
if perl $MYSQLTUNER_FILENAME --json --verbose --notbstat --forcemem=$MYSQL_MEMORY_LIMIT --outputfile="$MYSQLTUNER_REPORT" --defaults-file ~/.my.cnf > /dev/null; then

    echo -e "\033[34m\n* Sending metrics to Releem Cloud Platform...\033[0m"

    # Send metrics to Releem Platform. The answer is the configuration file for MySQL
    curl -s -d @$MYSQLTUNER_REPORT -H "x-releem-api-key: $RELEEM_API_KEY" -H "Content-Type: application/json" -X POST https://api.releem.com/v1/mysql -o "$MYSQLCONFIGURER_CONFIGFILE"

    echo -e "\033[34m\n* Downloading recommended MySQL configuration from Releem Cloud Platform...\033[0m"

    # Show recommended configuration and exit
    msg="\n\n\n#---------------Releem Agent Report-------------\n\n"
    printf "${msg}"

    echo -e "1. Recommended MySQL configuration downloaded to /tmp/.mysqlconfigurer/z_aiops_mysql.cnf"
    echo
    echo -e "2. To check MySQL Performance Score please visit https://app.releem.com/dashboard?menu=metrics"
    echo
    echo -e "3. To apply the recommended configuration please read documentation https://app.releem.com/dashboard"
    exit
else
    # If error then show report and exit
    errormsg="    \
    \n\n\n\n--------Releem Agent completed with error--------\n   \
    \nCheck /tmp/.mysqlconfigurer/mysqltunerreport.json for details \n \
    \n--------Please fix the error and run Releem Agent again--------\n"
    printf "${errormsg}" >&2
    exit 1
fi
