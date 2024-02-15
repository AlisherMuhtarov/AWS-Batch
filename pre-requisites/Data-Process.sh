#!/bin/bash

# Set your S3 bucket names
source_bucket="batch-customer-data-s3-bucket"
report_bucket="batch-report-s3-bucket"
temp_dir="/home/ec2-user/files"  # Specify the path to a temporary directory on your system

# Function to retrieve customer data from S3 bucket
retrieve_data() {
    # Sync data from S3 bucket to the temporary directory, excluding the source bucket folder
    aws s3 sync "s3://${source_bucket}/Customer-Data/" "$temp_dir"

    for ((i=1; i<=30; i++)); do
        file_name="file${i}.txt"
        cat "$temp_dir/$file_name" | grep "Customer Spend Amount" | cut -d ' ' -f 4 >> spend_amounts.txt
    done
}

# Function to calculate total, average, and find the customer with the most spending
calculate_metrics() {
    total=0
    max_spend=0

    while read -r spend_amount; do
        total=$((total + spend_amount))
        if ((spend_amount > max_spend)); then
            max_spend=$spend_amount
        fi
    done < spend_amounts.txt

    average=$((total / 30))
}

# Function to create a report and upload it to the new S3 bucket
create_report() {
    report_content="Total Spend: $total\nAverage Spend: $average\nCustomer with Max Spend: $max_spend"

    echo -e "$report_content" > report.txt
    aws s3 cp report.txt "s3://${report_bucket}/"
}

# Main script execution
retrieve_data
calculate_metrics
create_report

echo "Process completed successfully."
