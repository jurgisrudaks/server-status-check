#!/bin/bash

# Fix cron working directory to use relative paths
PREFIX=$(cd "$(dirname "$0")"; pwd)
cd $PREFIX

# Define global variables
CONFIG_FILE=config.conf

LOG_DIRECTORY=log/
LOG_FILE=${LOG_DIRECTORY}$(date +"%F").log
LOG_TIME_FORMAT=+%d-%m-%Y:%H:%M:%S

TMP_DIRECTORY=/tmp/statusCheck/
TMP_CONFIG_FILE=${TMP_DIRECTORY}config.conf
TMP_FAILS_COUNTER_FILE=${TMP_DIRECTORY}failed_counters.cfg

SERVERS_LIST=servers.list
SERVERS_TO_NOTIFY_ABOUT=()

declare -A COUNTERS

function log {
    echo "[`date $LOG_TIME_FORMAT`]: $1" >> $LOG_FILE
}

function createTempFiles {
    # Create temporary dir where to store tmp data
    mkdir -p $TMP_DIRECTORY
    mkdir -p $LOG_DIRECTORY
    
    # If failed counters file does not exist - create it
    if [ ! -e $TMP_FAILS_COUNTER_FILE ] ; then
        log "Temp counter file does not exist - creating (${TMP_FAILS_COUNTER_FILE})"
        touch $TMP_FAILS_COUNTER_FILE
    fi
    
    log "Initializing..."
}

function loadConfigFile {
    if [ -f ${CONFIG_FILE} ]; then
        # check if the file contains something we don't want
        if egrep -q -v '^#|^[^ ]*=[^;]*' "$CONFIG_FILE"; then
            #echo "Config file is unclean, cleaning it..." >&2
            log "Preparing config file... ($CONFIG_FILE)"

            # filter the original to a new file
            egrep '^#|^[^ ]*=[^;&]*'  "$CONFIG_FILE" > "$TMP_CONFIG_FILE"
            CONFIG_FILE="$TMP_CONFIG_FILE"
        fi
    else
        log "There is no configuration file! ($CONFIG_FILE)"
    fi
    
    source "$CONFIG_FILE"
}

function readCounters {
    # Read saved counters from temporary file
    log "Reading saved counters from file... ($TMP_FAILS_COUNTER_FILE)"
    
    IFS="="
    while read -r server count; do
        COUNTERS[$server]=${count//\"/}
    done < $TMP_FAILS_COUNTER_FILE
}

function cleanCountersFile {
    log "Cleaning counters file for new values to be written... ($TMP_FAILS_COUNTER_FILE)..."
    > $TMP_FAILS_COUNTER_FILE
}

function checkStatus {
    # Add newline to log file - just for readability
    echo "" >> $LOG_FILE

    # Loop through servr list and ping them
    while read line; do
        server=$(echo $line | sed $'s/\r//')
        formatted_server_name=${server//./_}
        responsitime_regex='= [^/]*/([0-9.]+).*ms'

        log "Checking status of ${server}..."
        [[ $(ping -q -c 1 $server) =~ $responsitime_regex ]] &> /dev/null && ms=${BASH_REMATCH[1]}

        # If ping successful then set fail counter to 0 otherwise increment it
        if [ $? -ne 0 ]; then
            COUNTERS[$formatted_server_name]=$((COUNTERS[$formatted_server_name]+1))
            log "${server} not responding - (count: ${COUNTERS[$formatted_server_name]})"
        else
            COUNTERS[$formatted_server_name]=0
            log "${server} is up - response time ${ms}ms!"
        fi
    done < $SERVERS_LIST
    
    # Add newline to log file - just for readability
    echo "" >> $LOG_FILE
}

function processCounters {
    log "Saving current failed counts to $TMP_FAILS_COUNTER_FILE and checking if there are servers for which we need to notify about"
    for i in "${!COUNTERS[@]}"; do
        server=$i
        count=${COUNTERS[$i]}

        case "$NOTIFY_METHOD" in
        "fail_count_reached" )      # Check if NOTIFY_WHEN_FAIL_COUNT is array
                                    if [[ "$(declare -p NOTIFY_WHEN_FAIL_COUNT)" =~ "declare -a" ]]; then
                                        # If is array check if current counter number is in array
                                        if [[ " ${NOTIFY_WHEN_FAIL_COUNT[@]} " =~ " ${count} " ]]; then
                                            # if so - add to SERVERS_TO_NOTIFY_ABOUT, so email includes this server
                                            SERVERS_TO_NOTIFY_ABOUT+=(${server//_/.})
                                        fi
                                    else
                                        # If NOTIFY_WHEN_FAIL_COUNT is not array just check if NOTIFY_WHEN_FAIL_COUNT value is equal to current counter
                                        if [ $count -eq $NOTIFY_WHEN_FAIL_COUNT ]; then
                                            # If fails counter have reached max fails allowed add server address to array
                                            SERVERS_TO_NOTIFY_ABOUT+=(${server//_/.})
                                        fi
                                    fi
                                    ;;
        "every_nth_time" )          if [ $count -ne 0 ] && [ $(( $count % $NOTIFY_EVERY_NTH_TIME )) -eq 0 ]; then
                                        SERVERS_TO_NOTIFY_ABOUT+=(${server//_/.})
                                    fi
                                    ;;
        *)                          echo "No method for meil sending specified - email will not be sent!" >> $LOG_FILE
                                    ;;
        esac

        # Write all counters to file
        echo "$server=$count" >> $TMP_FAILS_COUNTER_FILE
    done
}

function sendEmail {
    log "Preparing email message..."
    # Define new line character - default = \n
    newline="\n"

    # If email method is Mailgun change newline character to <br/> because mailgun sends email as HTML
    if [ "$EMAIL_METHOD" = "mailgun" ]; then
        newline="<br/>"
    fi

    # Prere email message/body
    message="Following servers are not responding:$newline"
    for server in "${SERVERS_TO_NOTIFY_ABOUT[@]}"; do
        # Loop through notify array and add servers to email message/body
        message+="$newline $server"
    done
    
    # Check which method has been defined in config and send out email with it
    case "$EMAIL_METHOD" in
        "smtp" )    log "Attempting to send email using SMTP"
                    sendEmail -f $EMAIL_FROM -t $EMAIL_TO \
                    -u "WARNING! Some servers are failing!" \
                    -m $message \
                    -a $LOG_FILE \
                    -s $EMAIL_SMTP_SERVER \
                    -o tls=$EMAIL_TLS \
                    -xu $EMAIL_USERNAME -xp $EMAIL_PASSWORD \
                    >> $LOG_FILE
                    ;;
        "mailgun" ) log "Attempting to send email using Mailgun"
                    curl -s --user "api:key-$EMAIL_MAILGUN_API_KEY" \
                    https://api.mailgun.net/v3/$EMAIL_MAILGUN_DOMAIN/messages \
                    -F from="Status check <$EMAIL_FROM>" \
                    -F to=$EMAIL_TO \
                    -F subject="WARNING! Some servers are failing!" \
                    -F html=$message \
                    -F attachment=@$LOG_FILE \
                    >> $LOG_FILE
                    ;;
        *)          echo "No method for meil sending specified - email will not be sent!" >> $LOG_FILE
                    ;;
    esac
}


# Prepare temporary folders and files to store temp data
createTempFiles

# Load config from config variables from config file
loadConfigFile

# Read failed counters from temporary storage
readCounters

# Clean up the failed counters file for new values to be written
cleanCountersFile

# Check server status and adjust counters accordingly
checkStatus

# Check fail counters and add server addresses to notify array if required
processCounters

# If there are any servers which require email notification send email
if [ ! -z "$SERVERS_TO_NOTIFY_ABOUT" ]; then
    sendEmail
fi

echo -e '\n' >> $LOG_FILE
