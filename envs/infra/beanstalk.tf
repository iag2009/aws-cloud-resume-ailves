## This is the application that will be created in the beanstalk
/*
resource "aws_elastic_beanstalk_application" "resume" {
  name        = var.project_long
  description = "My Beanstalk application for ${var.project_long}"
}*/
## This is the environment that will be created in the beanstalk
/*
resource "aws_elastic_beanstalk_environment" "resume" {
  name                = "${var.project_long}-env"
  application         = aws_elastic_beanstalk_application.resume.name
  solution_stack_name = "64bit Amazon Linux 2 v3.8.4 running Go 1"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.profile.name
  }
  
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "true"
  }
}*/
## This is the instance profile that will be created in the beanstalk
/*
resource "aws_iam_instance_profile" "profile" {
  name = "${var.project_long}-profile"
  role = aws_iam_role.role.name
}*/
## This is the role that will be created in the beanstalk
/*
resource "aws_iam_role" "role" {
  name = "${var.project_long}-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}*/