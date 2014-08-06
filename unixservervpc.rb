#!/usr/bin/ruby

# Script uses AWS Ruby SDK to create a VPC with a public and private subnet
# Launches a Amazon Linux EC2 instance based on AMI

require 'rubygems'
require 'aws-sdk'
require 'yaml'

aws_email="narshiva@amazon.com"
aws_name="Shiva Test Unix server"

# below is IAM credentials for my account
AWS.config(YAML.load(File.read('/Users/narshiva/.aws/cred.yml')))
ec2 = AWS::EC2.new(:region => "ap-southeast-2")

vpc = ec2.vpcs.create('10.0.0.0/16')
vpc.tag('Role', :value => 'GenericUnixHost')

gateway = ec2.internet_gateways.create
gateway.tag('Role', :value => 'GenericUnixHost')
gateway.attach(vpc)

public_route = vpc.route_tables.first
public_route.tag('Role', :value => 'GenericUnixHost')
public_route.create_route("0.0.0.0/0", internet_gateway: gateway.id)

public_subnet = vpc.subnets.create("10.0.0.0/24", availability_zone: "ap-southeast-2a")
public_subnet.tag('Role', :value => 'GenericUnixHost')

private_subnet = vpc.subnets.create("10.0.1.0/24", availability_zone: "ap-southeast-2b")
private_subnet.tag('Role', :value => 'GenericUnixHost')

# We need to create 2 security groups, one for public access, and one for private.
public_security_group = ec2.security_groups.create("public", vpc_id: vpc.id)
public_security_group.tag('Role', :value => 'GenericUnixHost')

private_security_group = ec2.security_groups.create("private", vpc_id: vpc.id)
private_security_group.tag('Role', :value => 'GenericUnixHost')

# The public security group should be allowed to talk to the world on tcp/22 (ssh) and the private one should only be allowed to talk to members of the public security group over tcp/22
public_security_group.authorize_ingress(:tcp, 22, "0.0.0.0/0")
private_security_group.authorize_ingress(:tcp, 22, {group_id: public_security_group.id})

# Create a network interface that you will attach a public IP to. This will be on the public subnet and use the public security group.
interface = ec2.network_interfaces.create(
  subnet: public_subnet,
  security_groups: public_security_group
)

sleep 2 until interface.status == :available
interface.tag('Role', :value => 'GenericUnixHost')

elastic_ip = ec2.elastic_ips.create(vpc: true)
elastic_ip.associate(network_interface: interface)

# Use this to fill in ELASTIC_IP later on
puts elastic_ip.public_ip

# Launch an instance into your VPC, since you’re specifiying to use an interface that’s already connected to your VPC you will be on its' subnet and use its' security groups.

amazon_linux_server = ec2.instances.create(
  availability_zone: "ap-southeast-2a",
  instance_type: "t2.micro",
  key_name: "shivaIAMUser",
  image_id: 'ami-d9fe9be3', # Amazon Linux 64 bit PV EBS
  network_interfaces: [{device_index: 0, network_interface_id: interface.id}]
)
amazon_linux_server.tag('Role', :value => 'GenericUnixHost')

# Wait around 30-60 seconds for the server to come up
sleep 2 until amazon_linux_server.status == :running
