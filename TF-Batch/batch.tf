
//----------------------COMPUTE INVIRONMENT----------------------//
resource "aws_batch_compute_environment" "demo" {
  compute_environment_name = "demo"

  compute_resources {
    instance_role = "arn:aws:iam::${data.aws_caller_identity.current.id}:instance-profile/AWS-Batch-EC2-Role"

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

  service_role = "arn:aws:iam::${data.aws_caller_identity.current.id}:role/aws-service-role/batch.amazonaws.com/AWSServiceRoleForBatch"
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