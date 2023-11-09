[![EPAM](https://img.shields.io/badge/Cloud&DevOps%20UA%20Lab%202nd%20Path-Cloud:%20AWS%20Task-orange)](./)
[![HitCount](https://hits.dwyl.com/HarrierPanels/my-java-project.svg?style=flat&show=unique)](http://hits.dwyl.com/HarrierPanels/AWS)
<br>
## Deploy https://github.com/FaztWeb/php-mysql-crud using CloudFormation as follows:

- Create a VPC.
- Create an Application Load Balancer.
- The balancer must be accessible from the Internet, but limited to certain IP addresses (85.223.209.18 EPAM VPN (vpn-ua.epam.com) and Home IP 44.195.37.94)
- One Listener listens at 80 and redirects to HTTPS<sup>[x]</sup>
- The second Listener listens to 443 and redirects everything to the target group<sup>[x]</sup>
- targets created by Auto Scaling Group
- Instances are created on a private subnet
- Unhealthy instances of the target group should be replaced with new ones
- When the number of requests increases to more than 10 per instance, increase the number of instances in the group. Maximum 3. And accordingly reduce when the “load” drops
- The project code must be on S3
- S3 bucket is not public
- Database in RDS. RDS has its own security group with access only to machines with Auto Scaling Group.
- Create a Mentor User in IAM so you he check it up
- DNS name for load balancer, managed via Route53<sup>[x]</sup>
- working HTTPS certificate managed via Certificate Manager<sup>[x]</sup>
[![MULTI-TIER](./crud-multi-tier.png)](./)
