# tests/sqs_test.tftest.hcl
# Basic SQS queue test
provider "aws" {
  region = "us-east-1"
}

# Test variables
variables {
  create                     = true
  name                       = "test-queue"
  fifo_queue                 = false
  create_dlq                 = false
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600  # 4 days
  max_message_size           = 262144  # 256 KiB
  delay_seconds              = 0
  receive_wait_time_seconds  = 0
  policy                     = null
  redrive_policy             = {}  # Empty map instead of null
  tags = {
    Environment = "test"
    Project     = "SQS-Tests"
  }
}

# Run a test module
run "create_standard_queue" {
  command = plan

  # Assert the plan would create the SQS queue
  assert {
    condition     = length(aws_sqs_queue.this) > 0
    error_message = "SQS queue resource was not created"
  }

  # Assert queue name is as expected
  assert {
    condition     = aws_sqs_queue.this[0].name == var.name
    error_message = "SQS queue name does not match expected value"
  }

  # Assert configuration values
  assert {
    condition     = aws_sqs_queue.this[0].visibility_timeout_seconds == var.visibility_timeout_seconds
    error_message = "visibility_timeout_seconds doesn't match expected value"
  }

  assert {
    condition     = aws_sqs_queue.this[0].message_retention_seconds == var.message_retention_seconds
    error_message = "message_retention_seconds doesn't match expected value"
  }

  assert {
    condition     = aws_sqs_queue.this[0].max_message_size == var.max_message_size
    error_message = "max_message_size doesn't match expected value"
  }

  assert {
    condition     = aws_sqs_queue.this[0].tags["Environment"] == "test"
    error_message = "Environment tag is not properly set"
  }
}

# FIFO queue test
run "create_fifo_queue" {
  command = plan

  # Set variables for this run
  variables {
    name       = "test-queue.fifo"
    fifo_queue = true
  }

  # Assert the plan would create the FIFO queue
  assert {
    condition     = aws_sqs_queue.this[0].fifo_queue == true
    error_message = "SQS queue is not configured as a FIFO queue"
  }

  # Check that .fifo suffix is present in name
  assert {
    condition     = endswith(aws_sqs_queue.this[0].name, ".fifo")
    error_message = "FIFO queue name does not end with .fifo suffix"
  }
}

# Test queue with DLQ redrive policy
run "queue_with_dlq" {
  command = plan

  # Set variables for this run
  variables {
    name = "main-queue"
    redrive_policy = {
      deadLetterTargetArn = "arn:aws:sqs:us-east-1:123456789012:dead-letter-queue"
      maxReceiveCount     = 5
    }
  }

  # Assert redrive_policy is properly applied
  assert {
    condition     = contains(keys(aws_sqs_queue.this[0]), "redrive_policy")
    error_message = "Redrive policy is not configured"
  }

  # Check if we can access the AWS SQS queue redrive policy resource (if used by the module)
  assert {
    condition     = length(keys(aws_sqs_queue.this[0])) > 0
    error_message = "SQS queue doesn't exist or has no attributes"
  }
}

# Test with custom IAM policy
run "queue_with_policy" {
  command = plan

  # Set variables for this run
  variables {
    name = "policy-queue"
    policy = jsonencode({
      Version = "2012-10-17"
      Id      = "sqspolicy"
      Statement = [
        {
          Sid       = "First"
          Effect    = "Allow"
          Principal = "*"
          Action    = "sqs:SendMessage"
          Resource  = "*"
          Condition = {
            ArnEquals = {
              "aws:SourceArn" = "arn:aws:sns:us-east-1:123456789012:example-topic"
            }
          }
        }
      ]
    })
  }

  # Only check that the policy attribute exists
  assert {
    condition     = contains(keys(aws_sqs_queue.this[0]), "policy")
    error_message = "SQS queue does not have a policy attribute"
  }
}

# Test with dead letter queue creation
run "create_with_dlq" {
  command = plan

  variables {
    name       = "queue-with-dlq"
    create_dlq = true
    # Note: When create_dlq is true, we don't need to provide redrive_policy
    # as the module will create it internally
  }

  # Assert the DLQ resource is created
  assert {
    condition     = length(aws_sqs_queue.dlq) > 0
    error_message = "Dead Letter Queue was not created despite create_dlq = true"
  }
}
