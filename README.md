## Provision a minimal DynamoDB table

The example configuration defines a DynamoDB table with pay-per-request billing and a composite primary key. This table will store environmental data (temperature, pressure, humidity) as events for logging devices.

1. Starting config:

    In `main.tf`:

    ```hcl
    terraform {
      required_version = "~> 1.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "4.8.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "3.1.2"
        }
      }
    }

    provider "aws" {
      region = "us-east-1"
    }

    resource "random_pet" "table_name" {
      prefix    = "environment"
      separator = "_"
      length    = 4
    }

    resource "aws_dynamodb_table" "environment" {
      name         = random_pet.table_name.id
      billing_mode = "PAY_PER_REQUEST"

      hash_key     = "deviceId"
      range_key    = "eventId"

      attribute {
        name = "deviceId"
        type = "S"
      }

      attribute {
        name = "eventId"
        type = "S"
      }
    }
    ```

    In `outputs.tf`:

    ```hcl
    output "environment_table_name" {
      description = "Name of the environment DynamoDB table"
      value       = aws_dynamodb_table.environment.name
    }

    output "environment_table_arn" {
      description = "ARN of the environment DynamoDB table"
      value       = aws_dynamodb_table.environment.arn
    }
    ```

    - All DynamoDB tables require a name and a primary key. This one's name is randomly generated, and it uses a composite primary key consisting of a hash (partition) key `deviceId`, and a range (sort) key `eventId`. Learn more about primary keys in the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html#HowItWorks.CoreComponents.PrimaryKey).
    - Only enumerate attributes that will be used for the primary key or other indexes. Your can store other attributes in your table, but they do not need to be defined in your configuration.
    - Pay-per-request billing (capacity) mode allows AWS to configure capacity for you. AWS recommends it for unpredictable workloads, but it can be more expensive than provisioned capacity. Learn more about capacity modes in the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html).

1. Init

    ```sh
    terraform init
    ```

1. Apply

    ```sh
    terraform apply
    ```

## Scale your DynamoDB table

With the `PAY_PER_REQUEST` billing mode, AWS manages your table's capacity for you. Review other ways to scale a dynamoDB table.

1. Configure provisioned capacity
1. Configure Autoscaling
1. Add global and local secondary indexes
1. Configure global tables
1. Manage TTL
1. Change table class

### Configure provisioned capacity

1. Change to provisioned billing (capacity) mode, and configure read/write capacity with variables.

    In `main.tf`:

    ```diff
     resource "aws_dynamodb_table" "environment_table" {
       name           = "environment"
    -  billing_mode   = "PAY_PER_REQUEST"
    +  billing_mode   = "PROVISIONED"
    +  read_capacity  = var.env_table_read_capacity
    +  write_capacity = var.env_table_write_capacity
    ```

    In `variables.tf`:

    ```hcl
    variable "env_table_read_capacity" {
      description = "Read capacity for environment table"
      type        = number
      default     = 5
    }

    variable "env_table_write_capacity" {
      description = "Write capacity for environment table"
      type        = number
      default     = 2
    }
    ```

1. Apply
    ```sh
    terraform apply
    ```

- Changing the billing (capacity) mode or scaling provisioned read/write capacity does not require replacing the table.
- Note: AWS limits changing a table's billing mode to once every 24 hours.
- Refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ProvisionedThroughput.html) for more details on provisioned capacity.

### Configure autoscaling

You can autoscale read and write capacity for tables in provisioned billing mode.

1. Add autoscaling resources. Also, ignore changes to read and write capacity.

    In `main.tf`, update:

    ```diff
       attribute {
         name = "eventId"
         type = "S"
       }

    +  lifecycle {
    +    ignore_changes = [read_capacity, write_capacity]
    +  }
    ```

    Also in `main.tf`, add read and write policies targeting your table:

    ```hcl
    resource "aws_appautoscaling_target" "environment_table_read_target" {
      max_capacity       = 20
      min_capacity       = 5
      resource_id        = "table/${aws_dynamodb_table.environment.name}"
      scalable_dimension = "dynamodb:table:ReadCapacityUnits"
      service_namespace  = "dynamodb"
    }

    resource "aws_appautoscaling_policy" "environment_table_read_policy" {
      name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.environment_table_read_target.resource_id}"
      policy_type        = "TargetTrackingScaling"
      resource_id        = aws_appautoscaling_target.environment_table_read_target.resource_id
      scalable_dimension = aws_appautoscaling_target.environment_table_read_target.scalable_dimension
      service_namespace  = aws_appautoscaling_target.environment_table_read_target.service_namespace

      target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
          predefined_metric_type = "DynamoDBReadCapacityUtilization"
        }

        target_value = 70.0
      }
    }

    resource "aws_appautoscaling_target" "environment_table_write_target" {
      max_capacity       = 10
      min_capacity       = 5
      resource_id        = "table/${aws_dynamodb_table.environment.name}"
      scalable_dimension = "dynamodb:table:WriteCapacityUnits"
      service_namespace  = "dynamodb"
    }

    resource "aws_appautoscaling_policy" "environment_table_write_policy" {
      name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.environment_table_write_target.resource_id}"
      policy_type        = "TargetTrackingScaling"
      resource_id        = aws_appautoscaling_target.environment_table_write_target.resource_id
      scalable_dimension = aws_appautoscaling_target.environment_table_write_target.scalable_dimension
      service_namespace  = aws_appautoscaling_target.environment_table_write_target.service_namespace

      target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
          predefined_metric_type = "DynamoDBWriteCapacityUtilization"
        }

        target_value = 70.0
      }
    }
    ```

1. Apply
    ```sh
    terraform apply
    ```

- Autoscaling can be configured without replacing the table.
- Use the `min_capacity` and `max_capcity` attributes to control the upper and lower bounds for both the read and write policies.
 - The initial values are still set by the variable, but will be dynamically controlled by autoscaling. Since autoscaling will control the read and write capacity, ignore changes to those fields. Otherwise, when you run `terraform apply`, terraform would report that these values have changed outside of terraform's control, and attempt to return them to the original values.
- For more information about autoscaling, refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.html).

### Add secondary indexes

Secondary indexes allow you to efficiently access data in your tables by indexes other than your primary key. There are two types: Local Secondary Indexes (LSIs) and Global Secondary Indexes (GSIs). Refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html) for more information about secondary indexes.

1. Add a local secondary index to `main.tf`:

    ```diff
       attribute {
         name = "eventId"
         type = "S"
       }

    +  attribute {
    +    name = "location"
    +    type = "S"
    +  }
    +
    +  local_secondary_index {
    +    name            = "by_location"
    +    range_key       = "location"
    +    projection_type = "ALL"
    +  }

       lifecycle {
         ignore_changes = [read_capacity, write_capacity]
       }
     }
    ```

1. Apply (the table will be replaced)
    ```sh
    terraform apply
    ```

- Range keys for LSIs must also be defined as attributes on the table.
- LSIs must be created when the table is created. Adding (or removing) one requires replacement. When terraform destroys your table, all of the items in it are lost.
- LSIs use the base table's read & write capacity, and have other limitations.
- Refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LSI.html) for more information.

1. Add a global secondary index to look up a `deviceId` by the `userId` to `main.tf`:

    ```diff
       attribute {
         name = "location"
         type = "S"
       }
    +
    +  attribute {
    +    name = "userId"
    +    type = "S"
    +  }

       local_secondary_index {
         name            = "by_location"
         range_key       = "location"
         projection_type = "ALL"
       }
    +
    +  global_secondary_index {
    +    name               = "by_user_id"
    +    hash_key           = "userId"
    +    write_capacity     = 5
    +    read_capacity      = 10
    +    projection_type    = "INCLUDE"
    +    non_key_attributes = ["userId", "location"]
    +  }
    ```

1. Add autoscaling configuration for the GSI to `main.tf`:
    ```hcl
    resource "aws_appautoscaling_target" "environment_table_by_user_id_read_target" {
      max_capacity       = 20
      min_capacity       = 5
      resource_id        = "table/${aws_dynamodb_table.environment.name}/index/by_user_id"
      scalable_dimension = "dynamodb:index:ReadCapacityUnits"
      service_namespace  = "dynamodb"
    }

    resource "aws_appautoscaling_policy" "environment_table_by_user_id_read_policy" {
      name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.environment_table_by_user_id_read_target.resource_id}"
      policy_type        = "TargetTrackingScaling"
      resource_id        = aws_appautoscaling_target.environment_table_by_user_id_read_target.resource_id
      scalable_dimension = aws_appautoscaling_target.environment_table_by_user_id_read_target.scalable_dimension
      service_namespace  = aws_appautoscaling_target.environment_table_by_user_id_read_target.service_namespace

      target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
          predefined_metric_type = "DynamoDBReadCapacityUtilization"
        }

        target_value = 70.0
      }
    }

    resource "aws_appautoscaling_target" "environment_table_by_user_id_write_target" {
      max_capacity       = 10
      min_capacity       = 5
      resource_id        = "table/${aws_dynamodb_table.environment.name}/index/by_user_id"
      scalable_dimension = "dynamodb:index:WriteCapacityUnits"
      service_namespace  = "dynamodb"
    }

    resource "aws_appautoscaling_policy" "environment_table_by_user_id_write_policy" {
      name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.environment_table_by_user_id_write_target.resource_id}"
      policy_type        = "TargetTrackingScaling"
      resource_id        = aws_appautoscaling_target.environment_table_by_user_id_write_target.resource_id
      scalable_dimension = aws_appautoscaling_target.environment_table_by_user_id_write_target.scalable_dimension
      service_namespace  = aws_appautoscaling_target.environment_table_by_user_id_write_target.service_namespace

      target_tracking_scaling_policy_configuration {
        predefined_metric_specification {
          predefined_metric_type = "DynamoDBWriteCapacityUtilization"
        }

        target_value = 70.0
      }
    }
    ```

1. Apply
    ```sh
    terraform apply
    ```

- GSIs can be created after the table, and have their own primary key and read & write capacities.
- Like LSIs, attributes used as keys for GSIs must be enumerated in the table definition.
- You can target autoscaling policies to GSIs as well, and AWS recommends doing so if you use autoscaling on the table itself.
- Refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html) for more info.

### Configure global tables

Global tables replicate your DynamoDB table across regions. Streaming must be enabled to use global tables, and your table must either be in the "PAY_PER_REQUEST" billing mode, or have autoscaling configured.

Configure global tables in terraform with `replicas` blocks.

1. Update `main.tf`.

    ```diff
     resource "aws_dynamodb_table" "environment_table" {
       name           = "environment"
       billing_mode   = "PROVISIONED"
       read_capacity  = var.env_table_read_capacity
       write_capacity = var.env_table_write_capacity

    +  stream_enabled   = true
    +  stream_view_type = "NEW_AND_OLD_IMAGES"
    +
    +  dynamic "replica" {
    +    for_each = var.replica_regions
    +    iterator = replica_region
    +
    +    content {
    +      region_name = replica_region.value
    +    }
    +  }
    ```

1. Add to `variables.tf`.

    ```hcl
    variable "replica_regions" {
      description = "AWS region names (eg 'us-east-1') to create Global Table replicas in"
      type        = list(string)
      default     = []
    }
    ```

1. Create a new file called 'terraform.tfvars' to set the value of `replica_regions`.

    ```hcl
    replica_regions = ["us-west-1", "ap-northeast-1"]
    ```

1. Apply
    ```sh
    terraform apply
    ```

- AWS Global Tables use streaming to replicate your table across regions. 
- In order to configure Global Tables, either autoscaling or the "PAY_PER_REQUEST" billing mode must already be configured on the table. Because of this, you cannot create a new dynamoDB table with autoscaling and global tables using Terraform. Terraform would attempt to create the table before the autoscaling resources, and would return an error from the AWS API.
    - You can use dynamic blocks to work around this limitation, as demonstrated in the example above. First create the table with `replica_regions` set to the default value (`[]`). Then, update it with the list of regions you want to replicate your table into.
    - Refer to [this issue](https://github.com/hashicorp/terraform-provider-aws/issues/13097#issuecomment-933806064) for more information about this limitation.
- If you are using autoscaling, you must also have autoscaling enabled on any GSIs for the table. (FIXME: I couldn't find this in the AWS documentation, but without AS on the GSI as well, I get the "...table must be austoscaled." error.)
- Refer to [the AWS documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables_reqs_bestpractices.html) for more information about global tables.
- This configuration is for Global Tables v2. For v1, refer to [the docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_global_table). (Maybe not mention this? Global Tables v2 was released in 2019.)

### Manage TTL

DynamoDB supports expiring items with TTL. This can help scale your table by removing items that are no longer needed. Add the following to `main.tf` to enable TTL.

    ```diff
     resource "aws_dynamodb_table" "environment" {
       name           = "environment"
       billing_mode   = "PROVISIONED"
       read_capacity  = var.env_table_read_capacity
       write_capacity = var.env_table_write_capacity

    +  ttl {
    +    enabled        = true
    +    attribute_name = "expiry"
    +  }
    ```

1. Apply.
    1. The attribute specified in `attribute_name` must be the epoch time in seconds. Do not enumerate it with an `attribute` block.
    1. Refer to the [AWS documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html) for more details.

### Change the table class

In addition to the default `Standard` table class, DynamoDB supports `Standard-Infrequent Access` tables for rarely-accessed data.

Configure your table's class in `main.tf`.

    ```diff
     resource "aws_dynamodb_table" "environment" {
       name           = "environment"
    +  table_class    = "STANDARD_INFREQUENT_ACCESS"
       billing_mode   = "PROVISIONED"
       read_capacity  = var.env_table_read_capacity
       write_capacity = var.env_table_write_capacity
    ```

1. Apply.
  1. Changing the table class does not require replacing the table.
  1. The AWS API requires that a change to a table's class be the only change made in a given request. Do not attempt to include any other changes to your table when changing the class.
      1. Tip: You can apply a refresh only plan (`terraform apply -refresh-only`) to ensure your table matches your configuration before updating your table's class.
  1. Refer to the [AWS Documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithTables.tableclasses.html) for more information.

## Use modules

The examples in this tutorial have used resources defined in the AWS provider to manage your DynamoDB table to demonstrate how each part of the configuration works. Consider using the https://github.com/terraform-aws-modules/terraform-aws-dynamodb-table module to manage your DynamoDB tables as well.

(FIXME: add configuration example with module)

## Clean up infrastructure

1. Destroy
    1. Note: Destroying a DynamoDB table automatically destroys any items in the table.

## Next steps

TBD
