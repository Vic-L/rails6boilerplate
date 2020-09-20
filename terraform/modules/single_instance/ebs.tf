# with reference to
# https://github.com/wardviaene/terraform-demo/blob/master/elasticbeanstalk.tf
# https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html

resource "aws_elastic_beanstalk_application" "main" {
  name = "${var.project_name}-${var.env}"
  description = "Elastic Beanstalk"
}

data "aws_iam_policy_document" "service" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "ec2" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "service" {
  name = "eb-${var.project_name}${var.env}-service-role"
  assume_role_policy = data.aws_iam_policy_document.service.json
}

resource "aws_iam_role" "ec2" {
  name = "eb-${var.project_name}${var.env}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2.json
}

resource "aws_iam_role_policy_attachment" "enhanced_health" {
  role = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "service" {
  role = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "eb-${var.project_name}${var.env}-instance-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role_policy_attachment" "web_tier" {
  role = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "worker_tier" {
  role = aws_iam_role.service.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_elastic_beanstalk_environment" "main" {
  name = "${var.project_name}-${var.env}"
  application = aws_elastic_beanstalk_application.main.name
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.11.10 running Ruby 2.6 (Puma)"

  ################
  # common settings
  ################

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = aws_iam_instance_profile.ec2.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "EC2KeyName"
    value = var.aws_key_pair.id
  }

#################
# single instance
#################

setting {
  namespace = "aws:elasticbeanstalk:environment"
  name = "EnvironmentType"
  value = "SingleInstance"
}

setting {
  namespace = "aws:autoscaling:launchconfiguration"
  name = "SecurityGroups"
  # use name for default vpc
  value = aws_security_group.web_server-single_instance.name
}

setting {
  namespace = "aws:autoscaling:asg"
  name = "MinSize"
  value = "1"
}

setting {
  namespace = "aws:autoscaling:asg"
  name = "MaxSize"
  value = "1"
}
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "RootVolumeSize"
    value = "16"
  }

  #################
  # enhanced health monitoring
  # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/health-enhanced-enable.html?icmpid=docs_elasticbeanstalk_console#health-enhanced-enable-config
  #################

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name = "SystemType"
    value = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application"
    name = "Application Healthcheck URL"
    value = "/healthcheck"
  }

  #################
  # env vars
  #################
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "DATABASE_URL"
    value = local.rds_database_url
  }

  # serve assets using static files
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "RAILS_SERVE_STATIC_FILES"
    value = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "RAILS_MASTER_KEY"
    value = var.master_key
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "RAILS_ENV"
    value = var.env
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "RACK_ENV"
    value = var.env
  }
}
