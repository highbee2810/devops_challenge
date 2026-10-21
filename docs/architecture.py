"""Generates docs/architecture.png  (pip install diagrams; requires graphviz)."""
from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECR, EC2, Fargate
from diagrams.aws.management import Cloudwatch, SystemsManager
from diagrams.aws.integration import SNS
from diagrams.aws.network import ALB, InternetGateway, NATGateway
from diagrams.aws.security import SecretsManager, IAM
from diagrams.aws.storage import S3
from diagrams.onprem.vcs import Github
from diagrams.onprem.client import Users, User
from diagrams.onprem.container import Docker

graph_attr = {"fontsize": "22", "pad": "0.6", "nodesep": "0.9", "ranksep": "1.3", "splines": "spline", "compound": "true"}

with Diagram("DevOps Challenge - Production Architecture (AWS, Jenkins, ECS Fargate)",
             filename="architecture", outformat="png", show=False,
             direction="TB", graph_attr=graph_attr):

    users = Users("End users")
    dev = User("Engineer")
    gh = Github("GitHub repo\n(app + Jenkinsfile + Terraform)")

    with Cluster("AWS Region (eu-west-1)"):
        ecr = ECR("ECR\nimmutable tags\nscan on push")
        s3 = S3("S3\nTerraform state")
        secrets = SecretsManager("Secrets Manager\nJenkins admin pw")
        ssm = SystemsManager("SSM Session Manager\n(port-forward, no inbound)")

        with Cluster("CloudWatch"):
            cw = Cloudwatch("Logs - Metrics\nAlarms - Dashboard")
            sns = SNS("SNS\nalarm e-mail")

        with Cluster("VPC 10.0.0.0/16"):
            igw = InternetGateway("Internet\nGateway")

            with Cluster("Public subnets (2 AZs)"):
                alb = ALB("Application\nLoad Balancer")
                nat = NATGateway("NAT GW\n(per AZ)")

            with Cluster("Private subnets (2 AZs)"):
                jenkins = EC2("Jenkins (EC2)\nDocker + JCasC\nIAM role, IMDSv2")
                with Cluster("ECS Fargate service\nautoscaling 2-6 tasks, circuit-breaker rollback"):
                    t1 = Fargate("Task AZ-a")
                    t2 = Fargate("Task AZ-b")

    # runtime traffic
    users >> Edge(label="HTTP(S)") >> igw >> alb
    alb >> Edge(label=":3000 /health") >> [t1, t2]
    [t1, t2] >> Edge(style="dotted", label="awslogs") >> cw
    cw >> Edge(style="dotted") >> sns >> Edge(style="dotted") >> dev

    # CI/CD flow
    dev >> Edge(label="git push") >> gh
    jenkins >> Edge(label="1 poll SCM", color="firebrick") >> gh
    jenkins >> Edge(label="2 test - build - scan\n3 push image", color="firebrick") >> ecr
    jenkins >> Edge(label="4 register task def\nupdate service", color="firebrick") >> t1
    ecr >> Edge(style="dashed", label="image pull") >> t2
    secrets >> Edge(style="dotted") >> jenkins
    dev >> Edge(style="dashed", label="admin UI") >> ssm >> Edge(style="dashed") >> jenkins
