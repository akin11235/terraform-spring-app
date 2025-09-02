terraform {
  backend "s3" {
    bucket         = "aws-bucket-java-app"          # S3 bucket name
    key            = "terraform.tfstate"            # Path to store state file
    region         = "us-east-1"                    # S3 bucket region
    dynamodb_table = "aws-dynamodb-java-app-deploy" # Optional - for state locking
    encrypt        = true                           # Encrypt state at rest
  }
}
