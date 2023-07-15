# Configure the AWS provider
provider "aws" {
  access_key =
  secret_key = 
  region = "eu-west-1"  # Replace with your desired region
}

#Creating a Key
resource "tls_private_key" "example" {
 algorithm = "RSA"
 rsa_bits = 4096
}
resource "aws_key_pair" "deployer" {
 key_name = "deployer-key1"
 public_key = "${tls_private_key.example.public_key_openssh}"
}

#Creating a Security group which allow port 80
resource "aws_security_group" "allow_tls" {
 name = "allow_tls"
 description = "Allow tls inbound traffic"
ingress {
 description = "tls from VPC"
 from_port = 80
 to_port = 80
 protocol = "TCP"
 cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
 description = "TLS from VPC"
 from_port = 22
 to_port = 22
 protocol = "Tcp"
 cidr_blocks = ["0.0.0.0/0"]
 }
egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
 }
tags = {
 Name = "allow_tls"
 }
}

#Launching EC2 instance
resource "aws_instance" "web" {
 depends_on = [aws_key_pair.deployer,aws_security_group.allow_tls,]
 ami = "ami-0fb2f0b847d44d4f0"
 instance_type = "t2.micro"
 key_name = "deployer-key1"
 security_groups = ["allow_tls"]
 connection {
 type = "ssh"
 user = "ec2-user"
 private_key = tls_private_key.example.private_key_pem
 host = aws_instance.web.public_ip
 }
provisioner "remote-exec" {
 inline = [
 "sudo yum install httpd php git -y",
 "sudo systemctl restart httpd",
 "sudo systemctl enable httpd",
 ]
 }
 tags = {
 Name = "WEBSERVER"
 }
}

#Launching a EBS volume and mounting it with /var/www/html folder
resource "aws_ebs_volume" "ebs" {
 availability_zone = aws_instance.web.availability_zone
 size = 1
 tags = {
 Name = "storage"
 }
}
resource "aws_volume_attachment" "ebs_att" {
 device_name = "/dev/sdh"
 volume_id = aws_ebs_volume.ebs.id
 instance_id = aws_instance.web.id
 force_detach = true
}
resource "null_resource" "nullremote1" {
  depends_on = [
    aws_volume_attachment.ebs_att,
    aws_instance.web,
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.example.private_key_pem
    host        = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/u16052642/worthwebsite.git /var/www/html/",
    ]
  }
}

#Launching a S3 bucket and uploading static website from github
resource "aws_s3_bucket" "b" {
 bucket = "worthbucketsite123"
 acl = "public-read"
tags = {
 Name = "My bucket"
 Environment = "Dev"
 }

 website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "null_resource" "nulllocal1" {
provisioner "local-exec" {
 command = "git clone https://github.com/u16052642/worthwebsite"
 }
}
resource "aws_s3_bucket_object" "object" {
 depends_on = [aws_s3_bucket.b]
 bucket = aws_s3_bucket.b.bucket
 key = "website"
 source = "worthwebsite"
 acl = "public-read"
}
locals {
 s3_origin_id = "S3-worthbucketsite123"
}

### Grant public read access to the S3 bucket
# Create IAM group for marketing users

resource "aws_iam_group" "marketing_group" {
  name = "marketing_group"
}

# Create IAM group for content editor
resource "aws_iam_group" "content_editor_group" {
  name = "content_editor_group"
}

# Create IAM group for HR
resource "aws_iam_group" "hr_group" {
  name = "hr_group"
}

# Create IAM user for Alice
resource "aws_iam_user" "alice" {
  name = "alice"
}

# Create IAM user for Malory
resource "aws_iam_user" "malory" {
  name = "malory"
}

# Create IAM user for Bobby
resource "aws_iam_user" "bobby" {
  name = "bobby"
}

# Create IAM user for Charlie
resource "aws_iam_user" "charlie" {
  name = "charlie"
}

# Add Alice and Malory to the marketing group
resource "aws_iam_group_membership" "marketing_group_membership" {
  name = "marketing_group_membership"
  users = [
    aws_iam_user.alice.name,
    aws_iam_user.malory.name
  ]
  group = aws_iam_group.marketing_group.name
}

# Add Bobby to the content editor group
resource "aws_iam_group_membership" "content_editor_group_membership" {
  name = "content_editor_group_membership"
  users = [
    aws_iam_user.bobby.name
  ]
  group = aws_iam_group.content_editor_group.name
}

# Add Charlie to the HR group
resource "aws_iam_group_membership" "hr_group_membership" {
  name = "hr_group_membership"
  users = [
    aws_iam_user.charlie.name
  ]
  group = aws_iam_group.hr_group.name
}

# Create IAM policy for marketing group to add to /news
resource "aws_iam_policy" "marketing_policy" {
  name        = "marketing_policy"
  description = "Allows marketing users to add to /news"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject"
        ],
        "Resource": "${aws_s3_bucket.b.arn}/news/*"
      }
    ]
  })
}

# Attach marketing policy to marketing group
resource "aws_iam_group_policy_attachment" "marketing_policy_attachment" {
  group      = aws_iam_group.marketing_group.name
  policy_arn = aws_iam_policy.marketing_policy.arn
}

# Create IAM policy for content editor group to edit the entire website
resource "aws_iam_policy" "content_editor_policy" {
  name        = "content_editor_policy"
  description = "Allows content editor to edit the entire website"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": "${aws_s3_bucket.b.arn}/*"
      }
    ]
  })
}

# Attach content editor policy to content editor group
resource "aws_iam_group_policy_attachment" "content_editor_policy_attachment" {
  group      = aws_iam_group.content_editor_group.name
  policy_arn = aws_iam_policy.content_editor_policy.arn
}

# Create IAM policy for HR group to update /people.html
resource "aws_iam_policy" "hr_policy" {
  name        = "hr_policy"
  description = "Allows HR to update /people.html"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject"
        ],
        "Resource": "${aws_s3_bucket.b.arn}/people.html"
      }
    ]
  })
}

# Attach HR policy to HR group
resource "aws_iam_group_policy_attachment" "hr_policy_attachment" {
  group      = aws_iam_group.hr_group.name
  policy_arn = aws_iam_policy.hr_policy.arn
}


#Create CloudFront for S3
resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [aws_instance.web,aws_s3_bucket_object.object,]
 origin {
 domain_name = "worthbucketsite123.s3.amazonaws.com"
 origin_id = "${local.s3_origin_id}"
 }
enabled = true
 is_ipv6_enabled = true
 comment = "Some comment"

default_cache_behavior {
 allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
 cached_methods = ["GET", "HEAD"]
 target_origin_id = "${local.s3_origin_id}"
forwarded_values {
 query_string = false
cookies {
 forward = "none"
 }
 }
viewer_protocol_policy = "allow-all"
 min_ttl = 0
 default_ttl = 3600
 max_ttl = 86400
 }

# Cache behavior with precedence 0
 ordered_cache_behavior {
 path_pattern = "/content/immutable/*"
 allowed_methods = ["GET", "HEAD", "OPTIONS"]
 cached_methods = ["GET", "HEAD", "OPTIONS"]
 target_origin_id = "${local.s3_origin_id}"
forwarded_values {
 query_string = false
 headers = ["Origin"]
cookies {
 forward = "none"
 }
 }
min_ttl = 0
 default_ttl = 86400
 max_ttl = 31536000
 compress = true
 viewer_protocol_policy = "redirect-to-https"
 }
price_class = "PriceClass_200" ##read up on this
restrictions {
 geo_restriction {
 restriction_type = "none"
 }
 }
tags = {
 Environment = "production"
 }
viewer_certificate {
 cloudfront_default_certificate = true
 }
}

#Updating the website code with cloudfront url
resource "null_resource" "cloudfront_url"{
 depends_on = [aws_cloudfront_distribution.s3_distribution]
 connection {
 type = "ssh"
 user = "ec2-user"
 private_key = tls_private_key.example.private_key_pem 
 host = aws_instance.web.public_ip
 }
provisioner "remote-exec" {
  inline = [
    "sudo sed -i '/</head>/i <link rel=\"stylesheet\" type=\"text/css\" href=\"https://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object.key}\" />' /var/www/html/index.html",
    "sudo systemctl restart httpd",
  ]
}
}


output "IP"{
 value=aws_instance.web.public_ip
}
