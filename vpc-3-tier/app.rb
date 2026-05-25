require 'aws-cdk-lib'
require_relative 'stacks/three_tier_stack'

EC2 = AWSCDK::AWSEC2
VPC = EC2::VPC
RDS = AWSCDK::AWSRDS
S3 = AWSCDK::AWSS3
ELBV2 = AWSCDK::AWSElasticloadbalancingv2
Cloudfront = AWSCDK::AWSCloudfront
Origins = AWSCDK::AWSCloudfrontOrigins

app = AWSCDK::App.new
VPCStack.new(app, 'VPCStack')

app.synth
