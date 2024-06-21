data "aws_availability_zones" "available" {}

resource "aws_vpc" "strapi_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "strapi-vpc"
  }
}

resource "aws_subnet" "strapi_subnet" {
  count             = 2
  vpc_id            = aws_vpc.strapi_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "strapi-subnet-${count.index}"
  }
}

resource "aws_security_group" "strapi_sg" {
  name        = "ec2-SG-strapi"
  description = "Strapi"

  vpc_id = aws_vpc.strapi_vpc.id 

  // Inbound rules (ingress)
  ingress {
    description = "Allow HTTP inbound traffic"
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Allow SSH inbound traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
    // Outbound rules (egress)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}


resource "aws_instance" "strapi" {
  ami                         = "ami-09040d770ffe2224f"
  instance_type               = "t2.medium"
  subnet_id              = aws_subnet.strapi_subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.strapi_sg.id]
  key_name = "strapi_key2"
  associate_public_ip_address = true
  user_data                   = <<-EOF
                                #!/bin/bash
                                sudo apt update
                                curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
                                sudo bash -E nodesource_setup.sh
                                sudo apt update && sudo apt install nodejs -y
                                sudo npm install -g yarn && sudo npm install -g pm2
                                echo -e "skip\n" | npx create-strapi-app simple-strapi --quickstart
                                cd simple-strapi
                                echo "const strapi = require('@strapi/strapi');
                                strapi().start();" > server.js
                                pm2 start server.js --name strapi
                                pm2 save && pm2 startup
                                sleep 360
                                EOF

  tags = {
    Name = "Strapi_Server"
  }
}

 


output "instance_ip" {
  value = aws_instance.strapi.public_ip
}

 
