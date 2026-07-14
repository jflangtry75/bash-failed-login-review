#!/bin/bash

LOGFILE="access_log.txt"
FAIL_THRESHOLD=5
WINDOW_SECONDS=900   # 15 minutes
REPORT_FILE="failed_login_report.csv"

declare -A fail_count
declare -A streak_start

echo "\"Timestamp\",\"User\",\"Application\",\"FailureCount\",\"StreakStartTime\",\"Flagged\"" >> "$REPORT_FILE"

while IFS=';' read -r timestamp user application status errorcode; do
    epoch=$(date -d "$timestamp" +%s)

    if [[ "$status" == "Success" ]]; then
        fail_count[$user]=0
        unset streak_start[$user]
        continue
    fi

    if [[ "$status" == "Failure" ]]; then
        if [[ -z "${streak_start[$user]}" ]]; then
            streak_start[$user]=$epoch
            fail_count[$user]=1
        else
            elapsed=$(( epoch - streak_start[$user] ))
            if (( elapsed <= WINDOW_SECONDS )); then
                fail_count[$user]=$(( fail_count[$user] + 1 ))
            else
                streak_start[$user]=$epoch
                fail_count[$user]=1
            fi
        fi

        flagged="False"
        if (( fail_count[$user] >= FAIL_THRESHOLD )); then
            flagged="True"
        fi

	streak_start_readable=$(date -d "@${streak_start[$user]}" -u +"%Y-%m-%dT%H:%M:%SZ")

	echo "\"$timestamp\",\"$user\",\"$application\",\"${fail_count[$user]}\",\"$streak_start_readable\",\"$flagged\"" >> "$REPORT_FILE"

        fi
done < "$LOGFILE"

echo "Report written to $REPORT_FILE"
