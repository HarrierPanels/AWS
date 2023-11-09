## Deploy https://github.com/FaztWeb/php-mysql-crud using CloudFormation as follows:

Create a VPC.
Create an Application Load Balancer.
- The balancer must be accessible from the Internet, but limited to certain IP addresses (85.223.209.18 EPAM VPN (vpn-ua.epam.com) and Home IP 44.195.37.94)
- One Listener listens at 80 and redirects to HTTPS[*]
- The second Listener listens to 443 and redirects everything to the target group<red>[*]</red>
- targets created by Auto Scaling Group
• Instances are created on a private subnet
• Unhealthy instances of the target group should be replaced with new ones
• When the number of requests increases to more than 10 per instance, increase the number of instances in the group. Maximum 3. And accordingly reduce when the “load” drops
• The project code must be on S3
 S3 bucket is not public
Database in RDS. RDS has its own security group with access only to machines with Auto Scaling Group.
Create a Mentor User in IAM so you he check it up
+ DNS name for load balancer, managed via Route53[*]
+ working HTTPS certificate managed via Certificate Manager[*]
