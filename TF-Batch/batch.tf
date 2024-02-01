
//----------------------COMPUTE INVIRONMENT----------------------//
resource "aws_batch_compute_environment" "demo" {
  compute_environment_name = "demo"

  compute_resources {
    instance_role = "arn:aws:iam::${data.aws_caller_identity.current.id}:instance-profile/Terraform-Server-Role"

    instance_type = [
      "optimal"
    ]

    max_vcpus = 6
    desired_vcpus = 3
    min_vcpus = 0


    security_group_ids = [
      "sg-0602605da5667f871"
    ]

    subnets = [
      "subnet-01b15e0262af666eb", "subnet-0eebce24507f2bbb6", "subnet-0b0a23f9960c0f286"
    ]

    type = "EC2"
  }

  service_role = "arn:aws:iam::${data.aws_caller_identity.current.id}:role/Terraform-Server-Role"
  type         = "MANAGED"
}

//----------------------JOB DEFINITION----------------------//
resource "aws_batch_job_definition" "test" {
  name = "demo-batch-definitions"
  type = "container"
  container_properties = jsonencode({
    command = [
      <<-EOT
        #!/bin/bash

        input_s3_bucket="batch-customer-data-s3-bucket"
        output_s3_bucket="your-output-s3-bucket"
        report_s3_bucket="batch-data-processing-report"
        report_s3_object_key="report.txt"

        # List all objects in the input S3 bucket
        objects=$(aws s3api list-objects-v2 --bucket "$input_s3_bucket" --query "Contents[].Key" --output json)

        # Process each object in the bucket
        for object_key in $objects; do
        # Skip directories or non-matching files
        if [[ "$object_key" != *".txt" ]]; then
            continue
        fi

        # Get the customer data from the current object
        customer_data=$(aws s3api get-object --bucket "$input_s3_bucket" --key "$object_key" /dev/stdout | jq -c '.')

        if [ $? -eq 0 ]; then
            # Process the customer data
            processed_data=$(echo "$customer_data" | jq '.[] | .ProcessedData = "Processed for " + .Name')
            total_spent=$(echo "$processed_data" | jq -r '[.[].TotalSpent] | add')
            average_spent=$(echo "$processed_data" | jq -r '[.[].TotalSpent] | add / length')
            customer_most_spent=$(echo "$processed_data" | jq -r 'max_by(.TotalSpent)')

            # Create the report JSON
            report_json="{
            \"TotalAmountSpent\": $total_spent,
            \"AverageAmountSpent\": $average_spent,
            \"CustomerWithMostSpending\": $customer_most_spent
            }"

            # Print the report JSON to the console
            echo "$report_json" | jq '.'

            # Upload the report to the output S3 bucket with a fixed key
            aws s3api put-object --bucket "$output_s3_bucket" --key "report.json" --body <(echo "$report_json")
        else
            echo "Failed to fetch customer data from input S3 bucket for object: $object_key"
        fi
        done

        # Consolidate reports and upload to the report bucket
        consolidated_report=$(aws s3api list-objects-v2 --bucket "$output_s3_bucket" --query "Contents[].Key" --output json \
        | jq -r '[.[] | select(.Key | contains("report.json"))] | [.[].Key | capture("(?<customer>.*?)_report.json").customer] | unique | map({customer: ., report: . + "_report.json"}) | {reports: .}')

        echo "$consolidated_report" | jq '.' > consolidated_report.json

        aws s3api create-bucket --bucket "$report_s3_bucket" --region YOUR_REGION

        aws s3api put-object --bucket "$report_s3_bucket" --key "$report_s3_object_key" --body <(echo "$consolidated_report" | jq -r '.')

      EOT
    ],
    image   = "busybox",
    resourceRequirements = [
      {
        type  = "VCPU"
        value = "1"
      },
      {
        type  = "MEMORY"
        value = "512"
      }
    ]

    mountPoints = [
      {
        sourceVolume  = "tmp"
        containerPath   = "/tmp"
        readOnly      = false
      }
    ]
  })
}

//----------------------JOB QUEUE----------------------//
resource "aws_batch_job_queue" "test_queue" {
  name     = "tf-batch-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.demo.arn
  ]
}