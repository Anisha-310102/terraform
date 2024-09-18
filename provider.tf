 terraform {
  backend "s3" {
   bucket         = "anisha-bucket"
    dynamodb_table = "state-lock"
    region         = "ap-southeast-2"
    key            = "global/mystatefile/terraform.tfstate"
   encrypt        = true
  }
 }



provider "aws" {
 region = "ap-southeast-2"
}
