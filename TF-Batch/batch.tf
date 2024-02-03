
//----------------------COMPUTE INVIRONMENT----------------------//
resource "aws_batch_compute_environment" "demo" {
  compute_environment_name = "demo"

  compute_resources {
    instance_role = "arn:aws:iam::${data.aws_caller_identity.current.id}:instance-profile/AWS-Batch-EC2-Role"

    instance_type = [
      "optimal"
    ]

    max_vcpus = 2
    desired_vcpus = 1
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
    image   = "public.ecr.aws/s6a4j9d6/demo-dock:latest",
    resourceRequirements = [
      {
        type  = "VCPU"
        value = "1"
      },
      {
        type  = "MEMORY"
        value = "500"
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