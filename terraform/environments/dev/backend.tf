terraform {
  backend "s3" {
    bucket         = "nf-supply-chain-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "nf-supply-chain-tflock"
    encrypt        = true
  }
}
