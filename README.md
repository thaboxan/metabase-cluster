# Week 6: Deploying Metabase on Amazon ECS with RDS PostgreSQL


## Task Overview

Deploy Metabase on Amazon ECS using the Fargate launch type and connect it to a PostgreSQL database hosted on Amazon RDS. This task demonstrates containerized application deployment with proper networking, security, and database connectivity.

## Architecture

The deployment includes:
- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **ECS Fargate**: Containerized Metabase application
- **Application Load Balancer**: For internet-facing access
- **RDS PostgreSQL**: Database backend in private subnets
- **Security Groups**: Proper network segmentation and access control

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0+)
- Basic understanding of containerization and AWS networking

## Deployment Instructions

### Step 1: Initialize Terraform

```bash
terraform init
```

### Step 2: Plan the Deployment

```bash
terraform plan
```

### Step 3: Apply the Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm the deployment.

### Step 4: Access Metabase

After successful deployment, Terraform will output the Metabase URL:

```
Outputs:

metabase_url = "http://metabase-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
```

Access this URL in your browser to reach the Metabase setup screen.

## Configuration Details

### Network Architecture

- **VPC CIDR**: `10.0.0.0/16`
- **Public Subnets**: `10.0.10.0/24` (us-east-1a), `10.0.11.0/24` (us-east-1b)
- **Private Subnets**: `10.0.20.0/24` (us-east-1a), `10.0.30.0/24` (us-east-1b)

### Security Groups

1. **ALB Security Group**: Allows HTTP (port 80) from internet
2. **ECS Security Group**: Allows port 3000 from ALB only
3. **RDS Security Group**: Allows PostgreSQL (port 5432) from ECS only

### Database Configuration

- **Engine**: PostgreSQL
- **Instance Class**: `db.t3.micro`
- **Username**: `metabaseuser`
- **Database Name**: `postgres`
- **Storage**: 20GB

### ECS Configuration

- **Launch Type**: Fargate
- **CPU**: 512 units
- **Memory**: 1024 MB
- **Docker Image**: `metabase/metabase:latest`

## Deliverables Checklist

### Screenshots Required

1. **RDS PostgreSQL Instance Details**
   - Show instance identifier, engine, and connection details
   - Verify instance is in "Available" status
   - Display security group configuration

2. **ECS Task Definition and Running Service**
   - Show task definition with container configuration
   - Display running service with desired/running task counts
   - Show task details including network configuration

3. **Security Group Rules**
   - ALB security group allowing HTTP from 0.0.0.0/0
   - ECS security group allowing port 3000 from ALB
   - RDS security group allowing port 5432 from ECS

4. **Metabase Setup Screen**
   - Initial Metabase welcome/setup page
   - Database connection configuration screen
   - Successful database connection confirmation

### Verification Steps

1. **Network Connectivity**
   - ECS tasks can reach RDS on port 5432
   - ALB can reach ECS tasks on port 3000
   - Internet traffic reaches ALB on port 80

2. **Service Health**
   - ECS service shows "RUNNING" status
   - ALB target group shows healthy targets
   - RDS instance shows "Available" status

3. **Application Functionality**
   - Metabase loads successfully via ALB URL
   - Database connection wizard completes
   - Initial admin user can be created

## Troubleshooting

### Common Issues

**Connection Refused Error**
- Ensure ALB target group has healthy targets
- Verify ECS service is running and registered with target group
- Check security group rules allow proper traffic flow

**Database Connection Failed**
- Verify RDS instance is in "Available" status
- Ensure security groups allow ECS to RDS communication
- Confirm database credentials match environment variables

**ECS Task Failing to Start**
- Check CloudWatch logs for container errors
- Verify task definition has correct environment variables
- Ensure execution role has proper permissions

### Useful Commands

**Check ECS Service Status**
```bash
aws ecs describe-services --cluster metabase-cluster --services metabase-service
```

**View ECS Task Logs**
```bash
aws logs describe-log-groups --log-group-name-prefix /ecs/metabase
```

**Test ALB Health**
```bash
curl -I http://your-alb-url/api/health
```

## Cleanup

To avoid ongoing charges, destroy the infrastructure when testing is complete:

```bash
terraform destroy
```

Type `yes` when prompted to confirm destruction.

## Security Considerations

- Database is isolated in private subnets
- Security groups follow principle of least privilege
- No direct internet access to ECS tasks or RDS
- All traffic flows through the Application Load Balancer

## Cost Optimization

- Using `db.t3.micro` for cost-effective testing
- Fargate with minimal CPU/memory allocation
- Single AZ deployment option available (modify subnets for production)

## Next Steps

After successful deployment:
1. Configure Metabase admin user
2. Connect to your data sources
3. Create dashboards and visualizations
4. Set up user access and permissions

## Resources

- [Metabase Documentation](https://www.metabase.com/docs/)
- [AWS ECS Fargate Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [RDS PostgreSQL Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)


<img width="1920" height="1080" alt="Screenshot (13)" src="https://github.com/user-attachments/assets/12f88ff2-f671-4e2d-b906-6ee55f2134a8" />
<img width="1920" height="1080" alt="Screenshot (12)" src="https://github.com/user-attachments/assets/759e2b07-f0eb-40ae-8e73-f2a596b0f805" />
<img width="1920" height="1080" alt="Screenshot (11)" src="https://github.com/user-attachments/assets/ffe48352-3b00-42ce-9c71-4c3d7027f454" />
<img width="1920" height="1080" alt="Screenshot (10)" src="https://github.com/user-attachments/assets/3d4a76e0-a7b1-4ac7-b84e-65aa2a243420" />
<img width="1904" height="1066" alt="Screenshot 2025-08-12 110746" src="https://github.com/user-attachments/assets/4f1e2107-c7b9-4554-a053-b985b04febce" />
<img width="1920" height="1080" alt="Screenshot (14)" src="https://github.com/user-attachments/assets/8a810341-05fe-4c15-adc5-9eea4d4dcde4" />
