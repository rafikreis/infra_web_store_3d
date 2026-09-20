# infra_web_store_3d

Infrastructure as Code (IaC) project that provisions the AWS cloud infrastructure for a **3D Printing E-Commerce Platform**.

The architecture is designed to support product catalogs, 3D asset uploads and storage, customer orders, and custom product workflows.

The environment uses **Terraform** to provision a multi-tier AWS architecture with containerized application workloads, isolated database storage, private networking, layered security controls, and remote Terraform state management.

---

## 🏛️ Architecture Overview

The infrastructure is distributed across **two Availability Zones** (`us-east-1a` and `us-east-1b`) to improve availability and reduce single points of failure.

```text
                                 ┌───────────────┐
                                 │   Internet    │
                                 └───────┬───────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │ Internet Gateway    │
                              └──────────┬──────────┘
                                         │
              ┌──────────────────────────┴──────────────────────────┐
              │                    Public Subnets                   │
              │                                                     │
              │     ┌─────────────────┐     ┌──────────────────┐   │
              │     │       ALB       │     │   NAT Gateway    │   │
              │     │  Load Balancer  │     │      + EIP       │   │
              │     └────────┬────────┘     └─────────▲────────┘   │
              └──────────────┼────────────────────────┼────────────┘
                             │                        │
                       Inbound HTTP              Outbound traffic
                             │                        │
                             ▼                        │
              ┌──────────────────────────────────────┴────────────┐
              │                 Private App Subnets               │
              │                                                   │
              │     ┌──────────────────────────────────────┐      │
              │     │          AWS ECS Fargate             │      │
              │     │                                      │      │
              │     │        Nginx / Application           │      │
              │     │       0.25 vCPU / 512 MB             │      │
              │     └───────────────────┬──────────────────┘      │
              └─────────────────────────┼─────────────────────────┘
                                        │
                                  PostgreSQL
                                     :5432
                                        │
                                        ▼
              ┌───────────────────────────────────────────────────┐
              │                  Private DB Subnets               │
              │                                                   │
              │     ┌──────────────────────────────────────┐      │
              │     │          Amazon RDS PostgreSQL        │      │
              │     │              db.t4g.micro             │      │
              │     └──────────────────────────────────────┘      │
              └───────────────────────────────────────────────────┘


              ┌──────────────────┐          ┌──────────────────┐
              │    Amazon ECR    │          │    Amazon S3     │
              │  Docker Images   │          │  Assets / Files  │
              └──────────────────┘          └──────────────────┘
```

### Core Architecture Components

* **Virtual Private Cloud (VPC):** Custom `10.0.0.0/16` network distributed across two Availability Zones with six dedicated subnets:

  * 2 Public Subnets
  * 2 Private Application Subnets
  * 2 Private Database Subnets

* **Ingress & Egress:** An **Application Load Balancer (ALB)** handles incoming HTTP traffic, while a **NAT Gateway** with an Elastic IP provides outbound internet connectivity for private resources.

* **Container Compute:** **AWS ECS Fargate** runs containerized application workloads inside private application subnets without requiring EC2 instance management.

* **Database:** **Amazon RDS PostgreSQL** is deployed in private database subnets with public access disabled.

* **Container Registry:** **Amazon ECR** stores Docker images with vulnerability scanning on push and a lifecycle policy that retains the five most recent image tags.

* **Application Storage:** **Amazon S3** provides private storage for application files and 3D assets, with CORS configuration for application integration.

* **Static Website Hosting:** A separate S3 bucket is configured to host the platform's static website.

* **Terraform State:** Terraform state is stored remotely in an S3 backend with versioning and encryption enabled.

---

## 🔒 Security Model

The architecture follows a layered security model using **AWS Security Groups** to control communication between each application tier.

```text
                  ┌──────────────────────┐
                  │    Public Internet   │
                  └──────────┬───────────┘
                             │
                          Port 80
                             │
                             ▼
                  ┌──────────────────────┐
                  │   ALB Security Group │
                  └──────────┬───────────┘
                             │
                          Port 80
                             │
                             ▼
                  ┌──────────────────────┐
                  │  App Security Group  │
                  └──────────┬───────────┘
                             │
                         Port 5432
                             │
                             ▼
                  ┌──────────────────────┐
                  │   DB Security Group │
                  └──────────────────────┘
```

### Security Rules

#### 1. ALB Security Group

Accepts HTTP traffic on port `80` from the public internet.

```text
0.0.0.0/0 → ALB :80
```

#### 2. Application Security Group

Accepts HTTP traffic on port `80` only from the ALB Security Group.

```text
ALB Security Group → App :80
```

The ECS tasks are not directly exposed to the internet.

#### 3. Database Security Group

Accepts PostgreSQL traffic on port `5432` only from the Application Security Group.

```text
App Security Group → RDS :5432
```

The database does not accept direct connections from the public internet.

---

## 🛠️ Infrastructure Specifications

| Component           | AWS Resource              | Specification                                      |
| ------------------- | ------------------------- | -------------------------------------------------- |
| IaC                 | Terraform                 | Remote S3 backend with versioning and encryption   |
| Network             | Amazon VPC                | `10.0.0.0/16` across `us-east-1a` and `us-east-1b` |
| Public Connectivity | Internet Gateway          | Internet access for public subnets                 |
| Public Ingress      | Application Load Balancer | HTTP traffic on port `80`                          |
| Private Egress      | NAT Gateway + Elastic IP  | Outbound internet access from private subnets      |
| Compute             | ECS Fargate               | `256 CPU` / `512 MB RAM`                           |
| Container           | Nginx                     | Containerized application workload                 |
| Database            | RDS PostgreSQL            | `db.t4g.micro`, 20 GB gp3                          |
| Registry            | Amazon ECR                | Scan on push + 5-tag lifecycle policy              |
| Application Storage | Amazon S3                 | Private bucket with CORS configuration             |
| Web Hosting         | Amazon S3                 | Static website hosting                             |
| Availability        | AWS Availability Zones    | `us-east-1a` + `us-east-1b`                        |

---

## 💡 Engineering Challenges & Solutions

### 1. Private Fargate Container Pull Failure

#### Problem

ECS Fargate tasks running inside private subnets were unable to retrieve container images because they did not have direct internet access.

This prevented the tasks from successfully starting when attempting to pull images from external registries.

#### Solution

A **NAT Gateway** was provisioned in a public subnet with an associated **Elastic IP**.

The private application route table was configured to forward outbound traffic through the NAT Gateway:

```text
Private Subnet
      │
      ▼
Route Table
0.0.0.0/0
      │
      ▼
NAT Gateway
      │
      ▼
Internet Gateway
      │
      ▼
Internet
```

This allows private ECS tasks to establish outbound connections without assigning public IP addresses to the containers.

---

### 2. ALB Target Group Dependency

#### Problem

During Terraform deployments, replacing an Application Load Balancer target group could result in dependency conflicts when Terraform attempted to destroy the existing resource before creating its replacement.

#### Solution

The target group uses Terraform's `create_before_destroy` lifecycle rule:

```hcl
lifecycle {
  create_before_destroy = true
}
```

This instructs Terraform to create the replacement resource before destroying the existing one, reducing deployment conflicts caused by resource dependencies.

---

### 3. Multi-Tier Network Isolation

The infrastructure separates the application into three network layers:

```text
┌───────────────────────────────┐
│        Public Layer           │
│                               │
│  ALB / NAT Gateway            │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│      Application Layer        │
│                               │
│  ECS Fargate                  │
│  Private Subnets              │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│        Database Layer         │
│                               │
│  RDS PostgreSQL               │
│  Private DB Subnets           │
└───────────────────────────────┘
```

This separation limits direct network exposure and allows security rules to be applied independently to each tier.

---

## 📁 Repository Structure

```text
infra_web_store_3d/
│
├── backend.tf
│   └── Remote Terraform backend configuration
│
├── bootstrap.tf
│   └── S3 state bucket and versioning configuration
│
├── container_registry.tf
│   └── ECR repository, scanning and lifecycle policy
│
├── database.tf
│   └── RDS PostgreSQL instance and subnet group
│
├── ecs.tf
│   └── ECS cluster, task definition and Fargate service
│
├── load_balancer.tf
│   └── ALB, target group and HTTP listener
│
├── nat_gateway.tf
│   └── Elastic IP, NAT Gateway and private routing
│
├── outputs.tf
│   └── Terraform outputs for infrastructure endpoints
│
├── s3_website.tf
│   └── S3 static website hosting configuration
│
├── security_groups.tf
│   └── ALB, application and database Security Groups
│
├── storage.tf
│   └── Private S3 application storage and CORS
│
└── vpc.tf
    └── VPC, Internet Gateway, subnets and route tables
```

---

## 🚀 Deployment

### Prerequisites

Before deploying the infrastructure, install:

* AWS CLI
* Terraform CLI
* Docker
* Git
* An AWS account with the required permissions

### Configure AWS Credentials

Configure the AWS CLI:

```bash
aws configure
```

Verify the configuration:

```bash
aws sts get-caller-identity
```

### Verify Terraform

```bash
terraform -v
```

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/rafikreis/infra_web_store_3d.git

cd infra_web_store_3d
```

### 2. Initialize Terraform

```bash
terraform init
```

Terraform will initialize the providers and configure the remote state backend.

### 3. Validate the Configuration

```bash
terraform validate
```

### 4. Review the Infrastructure Plan

```bash
terraform plan
```

Review the resources Terraform intends to create before applying the infrastructure.

### 5. Deploy

```bash
terraform apply
```

Confirm the deployment when prompted.

---

## 📤 Terraform Outputs

After deployment, Terraform exposes important infrastructure endpoints through the configured outputs.

For example:

```bash
terraform output
```

Depending on the current configuration, outputs may include:

* Application Load Balancer DNS name
* S3 website endpoint
* Other infrastructure identifiers

The ALB DNS name can be retrieved with:

```bash
terraform output alb_dns_name
```

---

## 🗃️ Terraform State Management

The project uses a remote **Amazon S3 backend** to store Terraform state.

The backend provides:

* Centralized state storage
* State persistence
* Versioning
* Encryption
* Reduced risk of losing local state

The repository separates the bootstrap configuration required to create the state infrastructure from the main infrastructure deployment.

---

## 📊 Infrastructure Flow

The resulting request flow is:

```text
                         Client
                           │
                           │ HTTP :80
                           ▼
                  ┌─────────────────┐
                  │      ALB        │
                  └────────┬────────┘
                           │
                           │ HTTP :80
                           ▼
                  ┌─────────────────┐
                  │   ECS Fargate   │
                  │ Private Subnet  │
                  └────────┬────────┘
                           │
                           │ PostgreSQL :5432
                           ▼
                  ┌─────────────────┐
                  │  RDS PostgreSQL │
                  │ Private Subnet │
                  └─────────────────┘
```

Outbound traffic from private ECS tasks follows:

```text
ECS Fargate
     │
     ▼
Private Route Table
     │
     ▼
NAT Gateway
     │
     ▼
Elastic IP
     │
     ▼
Internet Gateway
     │
     ▼
Internet
```

---

## 🔮 Future Improvements

The current infrastructure provides the foundation for the 3D printing platform. Potential future improvements include:

* HTTPS with AWS Certificate Manager
* Route 53 custom domain
* Auto Scaling for ECS services
* ECS deployment strategies
* CloudWatch monitoring and alarms
* AWS WAF integration
* CloudFront distribution
* S3 presigned URLs for secure 3D asset uploads
* Secrets Manager for database credentials
* RDS Multi-AZ configuration
* CI/CD pipeline using GitHub Actions
* Infrastructure testing and automated validation
* Centralized logging
* Backup and disaster recovery strategy

---

## 🧰 Technologies

* **Terraform**
* **AWS VPC**
* **AWS ECS**
* **AWS Fargate**
* **Application Load Balancer**
* **Amazon RDS PostgreSQL**
* **Amazon ECR**
* **Amazon S3**
* **NAT Gateway**
* **Internet Gateway**
* **AWS Security Groups**
* **Docker**
* **Infrastructure as Code**

---

## 📌 Project Goal

This project was created as a practical **AWS Cloud and Infrastructure as Code portfolio project**, focusing on designing and provisioning a production-oriented cloud foundation for a 3D printing e-commerce platform.

The main objective is to demonstrate practical knowledge of:

* AWS networking
* Cloud security
* Containerized workloads
* Managed databases
* Object storage
* Infrastructure as Code
* Terraform state management
* High-availability architecture
* Private/public subnet design
* AWS resource integration
* Troubleshooting and infrastructure deployment

---

## 👤 Author

**Rafik Reis**

Software Engineering student focused on **Cloud, AWS, Infrastructure as Code, Data and AI**.

GitHub: [github.com/rafikreis](https://github.com/rafikreis)
