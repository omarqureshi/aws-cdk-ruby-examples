class VPCStack < AWSCDK::Stack

  VPC_CIDR = "10.0.0.0/16"

  def initialize(scope, construct_id, **args)
    super
    audit_bucket = create_audit_bucket
    react_bucket = create_react_bucket
    vpc = create_vpc(audit_bucket)
    lb = create_loadbalancer(vpc)
    create_cloudfront_distribution(react_bucket, lb)
    create_mysql(vpc)
  end

  def create_cloudfront_distribution(react_bucket, lb)
    origin = Origins::S3BucketOrigin.with_origin_access_control(
      react_bucket, {
        origin_access_levels: [Cloudfront::AccessLevel::READ, Cloudfront::AccessLevel::LIST]
      }
    )
    Cloudfront::Distribution.new(
      self,
      "ReactDistribution",
      default_behavior: {
        origin: origin
      },
      additional_behaviors: {
        "/api/*" => {
          origin: Origins::LoadBalancerV2Origin.new(lb),
          allowed_methods: Cloudfront::AllowedMethods.ALLOW_ALL
        }
      }
    )
  end

  def create_react_bucket
    S3::Bucket.new(
      self,
      "ReactBucket",
      bucket_name_prefix: "react-application",
      bucket_namespace: S3::BucketNamespace::ACCOUNT_REGIONAL,
      block_public_access: S3::BlockPublicAccess.BLOCK_ALL,
      access_control: S3::BucketAccessControl::PRIVATE,
      enforce_ssl: true
    )
  end

  def create_loadbalancer(vpc)
    lb = ELBV2::ApplicationLoadBalancer.new(
      self,
      'PublicLoadBalancer',
      vpc: vpc,
      internet_facing: true
    )
    
    listener = lb.add_listener("PublicListener", port: 80)
    listener.add_action(
      "FixedResponse",
      action: ELBV2::ListenerAction.fixed_response(
        200,
        content_type: "text/plain",
        message_body: "OK"
      )
    )
    lb
  end

  def create_audit_bucket
    S3::Bucket.new(
      self,
      "Auditbucket",
      bucket_name_prefix: "audit",
      bucket_namespace: S3::BucketNamespace::ACCOUNT_REGIONAL
    )
  end

  def create_vpc(audit_bucket)
    vpc_name = "myvpc"
    VPC.new(
      self,
      'VPC',
      vpc_name: vpc_name,
      ip_addresses: EC2::IpAddresses.cidr(VPC_CIDR),
      subnet_configuration: [
        subnet_configuration("public", EC2::SubnetType::PUBLIC, 24),
        subnet_configuration("workload", EC2::SubnetType::PRIVATE_WITH_EGRESS, 24),
        subnet_configuration("private", EC2::SubnetType::PRIVATE_ISOLATED, 24)
      ],
      nat_gateways: 1,
      max_azs: 3,
      flow_logs: {
        'flow-logs-s3': {
          destination: EC2::FlowLogDestination.to_s3(
            audit_bucket,
            "vpc-logs/#{vpc_name}"
          )
        }
      }
    )
  end

  def subnet_configuration(name, type, mask)
    EC2::SubnetConfiguration.new(
      name: name,
      subnet_type: type,
      cidr_mask: mask
    )
  end

  def create_mysql(vpc)
    version = RDS::MysqlEngineVersion.VER_8_0
    RDS::DatabaseInstance.new(
      self,
      "MySQL",
      engine: RDS::DatabaseInstanceEngine.mysql(version: version),
      instance_type: EC2::InstanceType.of(EC2::InstanceClass::T3, EC2::InstanceSize::MEDIUM),
      vpc_subnets: { subnet_type: EC2::SubnetType::PRIVATE_ISOLATED },
      vpc: vpc,
      port: 3306,
      removal_policy: AWSCDK::RemovalPolicy::DESTROY,
      deletion_protection: false
    )
  end
end
