# Here is a bash script that uploads local Docker images
# to an Amazon Elastic Container Registry (ECR) 
# private registry:

#!/bin/bash

# Define the name of the ECR repository
repository_name="my-private-registry"

# Login to AWS ECR
$(aws ecr get-login --no-include-email)

# Build a Docker image from the local Dockerfile
docker build -t $repository_name .

# Tag the Docker image with the repository URI
docker tag $repository_name:latest aws_account_id.dkr.ecr.region.amazonaws.com/$repository_name:latest

# Push the Docker image to the ECR repository
docker push aws_account_id.dkr.ecr.region.amazonaws.com/$repository_name:latest


# In this script, you will need to replace aws_account_id 
# and region with your AWS account ID and the AWS region 
# that the ECR repository is located in, respectively. 
# The script first logs into AWS ECR using the 
# aws ecr get-login command, then builds a Docker 
# image from the local Dockerfile using the docker 
# build command, tags the image with the repository URI, 
# and finally pushes the image to the ECR repository 
# using the docker push command.