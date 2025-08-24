################################################# Network Resources #################################################
module "network-components" {
  source                   = "./modules/network-components"
  vpc_name                 = "${var.prefix}-vpc"                 // Name of VPC going to be provisioned      
  vpc_cidr                 = var.vpc_cidr                        // CDIR value for VPC
  azs                      = var.azs                             // list of Availibility zones
  ig_name                  = "${var.prefix}-internet-gateway"    // name for Internet gateway going to be attached
  public_subnets_cidrs    = var.public_subnets_cidrs          // List of CIDR values for public subnet
  public_route_table_name  = "${var.prefix}-public-route-table"  // name for route table to be used for public subnet
  private_subnets_cidrs   = var.private_subnets_cidrs          // List of CIDR values for private subnet
  nat_name                 = "${var.prefix}-nat-gateway"         // name for  nat-gateway going to be associated with the private subnets
  private_route_table_name = "${var.prefix}-private-route-table" // name for route table to be used for public subnet
  public_acl_name          = "${var.prefix}-public-acl-name"     // name for ACL going to be used for public subnets
  private_acl_name         = "${var.prefix}-private-acl-name"    // name for ACL going to be used for public subnets
}
################################################# Jenkins Resources #################################################
module "Jenkins-server" {
  source            = "./modules/EC2"
  ami               = var.ami                                        // AMI ID going to be used
  subnet_id         = module.network-components.public_subnet_ids[0] // Id of subnet in which the instance going to be provisioned
  volume            = var.volume                                     // Disk volume size  going to be attached with the Instance
  user_data         = "script.sh"                                    // path of user-data script which is going to be executed during Instance provision
  profile_name      = "Jenkins-iam-role-profile"                     // name for Instance profile that will be used in for this Instance
  instance_name     = "${var.prefix}-jenkins-server"                 // name of the instance that is going to be launched
  instance_type     = var.instance_type                              // type of the insance going to be used
  security_group_id = module.security-group.security_group_id        // ID of security group going to be attached with Instance
  key_name          = module.key-pair.key_name                       // name of the ssh key-pairs going to be attached with Instance
  iam_role          = module.iam-role.iam_role_name                  // name of IAM role going to used for this Instance
}

module "security-group" {
  source  = "./modules/security-groups"
  sg_name = "${var.prefix}-Jenkins-security-group"
  vpc_id  = module.network-components.vpc_id // ID of VPC on which the security group is going to be attached
  ingress_rules = {                          // ingress rules that will be attached with the security group
    "jenkins" = {
      type        = "ingress"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["49.207.186.65/32", "192.30.252.0/22", "185.199.108.0/22", "140.82.112.0/20", "143.55.64.0/20"]
    }

    "ssh" = {
      type        = "ingress"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["49.207.186.65/32"]
    }

    "smtp" = {
      type        = "ingress"
      from_port   = 25
      to_port     = 25
      protocol    = "tcp"
      cidr_blocks = ["49.207.186.65/32"]
    }

  }
}

module "iam-role" {
  source    = "./modules/iam-role"
  
  role_name = "jenkins-s3-role" // name for the IAM role going to be created
  // Assume role policy going to be attached with role
  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "ec2.amazonaws.com"
      },
      "Action" : "sts:AssumeRole"
    }
  ]
} 
EOF
}

module "custom_iam_policy" {
  source   = "./modules/iam-role-policy"
  iam_role = module.iam-role.iam_role_name // name of IAM -role to which the policies has to be attached
  policies = {                             // Custom IAM policies
    "EC2-bucket-1" = {
      description = "allows s3 all access"
      document    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1711560567714",
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "${module.s3-bucket.bucket_arns[0]}"
    }
  ]
}
EOF
    }
    "EC2-bucket-2" = {
      description = "allows s3 all access"
      document    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1711560567714",
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "${module.s3-bucket.bucket_arns[1]}"
    }
  ]
}
EOF
    }
    "EC2-cloudfront" = {
      description = "allows cloudfront all access"
      document    = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "cloudfront:*",
            "Resource": "*"
        }
    ]
}
EOF
    }
    "session-management" = {
      description = "session"
      document    = <<EOF
{

    "Version": "2012-10-17",

    "Statement": [

        {

            "Effect": "Allow",

            "Action": [

                "cloudwatch:PutMetricData",

                "ds:CreateComputer",

                "ds:DescribeDirectories",

                "ec2:DescribeInstanceStatus",

                "logs:*",

                "ssm:*",

                "ec2messages:*"

            ],

            "Resource": "*"

        },

        {

            "Effect": "Allow",

            "Action": "iam:CreateServiceLinkedRole",

            "Resource": "arn:aws:iam::*:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM*",

            "Condition": {

                "StringLike": {

                    "iam:AWSServiceName": "ssm.amazonaws.com"

                }

            }

        },

        {

            "Effect": "Allow",

            "Action": [

                "iam:DeleteServiceLinkedRole",

                "iam:GetServiceLinkedRoleDeletionStatus"

            ],

            "Resource": "arn:aws:iam::*:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM*"

        },

        {

            "Effect": "Allow",

            "Action": [

                "ssmmessages:CreateControlChannel",

                "ssmmessages:CreateDataChannel",

                "ssmmessages:OpenControlChannel",

                "ssmmessages:OpenDataChannel"

            ],

            "Resource": "*"

        }

    ]

}
EOF
    }
    "EC2-secrets-manager" = {
      description = "allows cloudfront all access"
      document    = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowJenkinsToGetSecretValues",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "*"
        },
        {
            "Sid": "AllowJenkinsToListSecrets",
            "Effect": "Allow",
            "Action": "secretsmanager:ListSecrets",
            "Resource": "*"
        }
    ]
}
EOF
    }
  }
}

module "key-pair" {
  source   = "./modules/key-pair"
  key_name = "${var.prefix}-Jenkins-server-key"
}
################################################# S3-bucket Resources #################################################
module "s3-bucket" {
  source         = "./modules/s3-bucket"
  s3_names       = var.s3_names                     // list of names for for the bucket
  cloudfront_arn = module.cloudfront.cloudfront_arn // The CloudFront ARN intended for inclusion in the bucket policy.
}

module "primary-bucket-policy" {
  source      = "./modules/s3-bucket-policy"
  bucket_name = module.s3-bucket.bucket_names[0] // name of the bucket to which the policy has to be attached
  // Bucket policy
  policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "${module.s3-bucket.bucket_arns[0]}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${module.cloudfront.cloudfront_arn}"
        }
      }
    },
    {
      "Sid": "AllowIAMRoleAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${module.iam-role.iam_arn}"
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${module.s3-bucket.bucket_arns[0]}",
        "${module.s3-bucket.bucket_arns[0]}/*"
      ]
    }
  ]
}

EOF
}
module "failover-bucket-policy" {
  source      = "./modules/s3-bucket-policy"
  bucket_name = module.s3-bucket.bucket_names[1] // name of the buket to which the policy has to be attached
  // bucket policy
  policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "${module.s3-bucket.bucket_arns[1]}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${module.cloudfront.cloudfront_arn}"
        }
      }
    },
    {
      "Sid": "AllowIAMRoleAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${module.iam-role.iam_arn}"
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${module.s3-bucket.bucket_arns[1]}",
        "${module.s3-bucket.bucket_arns[1]}/*"
      ]
    }
  ]
}

EOF
}
################################################# ACM Resource #################################################
module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name // Domain for which the certificate needs to be generated
}
################################################# Cloudfront Resource #################################################
module "cloudfront" {
  source   = "./modules/cloudfront"
  oac_name = "${var.prefix}-s3-origin-oac"                  // name for origin access control 
  oac_desc = "bucket can be access only through cloudfront" // OAC Description
  origins = {                                               // origins of cloudfront
    "my-blog.live-primary" = {
      domain_name = module.s3-bucket.regional_domain_names[0]
    }
    "my-blog.live-failover" = {
      domain_name = module.s3-bucket.regional_domain_names[1]
    }
  }
  type            = "s3"                       // origin type
  //aliases         = ["my-blog.1cloudhub.com"]  // custom domain name going to be used with the cloudfront
  //certificate_arn = module.acm.certificate_arn // ARN of custom ACM ceretificate
}

################################################# Route53 Resource #################################################
# module "route-53" {
#   source                 = "./modules/route53"
#   domain_name            = var.domain_name                          // Custom domain name     
#   cloudfront_domain_name = module.cloudfront.cloudfront_domain_name // Cloudfront domain name
#   cloudfront_zone_id     = module.cloudfront.cloudfront_zone_id     // Cloudfront zone id 
#   certificate_arn        = module.acm.certificate_arn               // ACM certificate ARN
#   resource_record_name   = module.acm.resource_record_name          // ACM ceritificate record name
#   resource_record_value  = module.acm.resource_record_value         // ACM certificate record value
#   resource_record_type   = module.acm.resource_record_type          // ACM record type
# }
################################################# Secret Manager Resources #################################################
module "secrets-manager-pat-token" {
  source        = "./modules/secret-manager"
  secret_name   = "pat-token-github" // name for secret
  description   = "github pat-token" // description about the secret value
  secret_string = var.tf_token       // secret value need to be stored
  tags = {
    "jenkins:credentials:type"     = "usernamePassword"
    "jenkins:credentials:username" = "sundharabalajikl@gmail.com"
  }
}

module "secrets-manager-gmail" {
  source        = "./modules/secret-manager"
  secret_name   = "smtp-mail-pass"     // name for secret
  description   = "gmail app-password" // description about the secret value
  secret_string = var.tf_app_pass      // secret value need to be stored
  tags = {
    "jenkins:credentials:type"     = "usernamePassword"
    "jenkins:credentials:username" = "sundharabalajikl@gmail.com"
  }
}
################################################# Github Resource #################################################
# resource "github_repository_file" "output_json" {
#   repository = "Infra-repo"  // repositoy name 
#   branch     = "main"        // branch name
#   file       = "output.json" // name for the file  that has to be created in the repository
#   content    = <<-EOT
#     {
#       "bucket_names": ${jsonencode(module.s3-bucket.bucket_names)},
#       "cloudfront_id": "${module.cloudfront.cloudfront_id}"
#     }
#   EOT

#   commit_message      = "Update output.json"           // commit message for the commit
#   commit_author       = "Terraform User"               // commit author of the commit
#   commit_email        = "sundharabalaji@1cloudhub.com" // commit email of the commit
#   overwrite_on_create = true

#   depends_on = [
#     module.cloudfront,
#     module.s3-bucket
#   ]
# }
