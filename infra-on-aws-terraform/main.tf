#Cloud Provider Access

provider "aws" {
 #access_key = "${var.access_key}"
 #secret_key = "${var.secret_key}"
 region     = "${var.region}"
}

# Setting up VPC
resource "aws_vpc" "mw_vpc" {
  cidr_block = "${var.aws_cidr_vpc}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    Name = "MediaWikiVPC"
  }
}

# Creating Internet Gateway to provide Internet to the Subnet
#resource "aws_internet_gateway" "mw_igw" {
#    vpc_id = "${aws_vpc.mw_vpc.id}"
#    tags {
#        Name = "MediaWiki Internet Gateway for Subnet1"
#    }
#}

# Grant the VPC internet access on its main route table

#resource "aws_route_table" "mw_rt" {
#  vpc_id = "${aws_vpc.mw_vpc.id}"
#  route {
#        cidr_block = "0.0.0.0/0"
#        gateway_id = "${aws_internet_gateway.mw_igw.id}"
#    }
#}

#resource "aws_route_table_association" "PublicAZA" {
#    subnet_id = "${aws_subnet.mw_subnet1.id}"
#    route_table_id = "${aws_route_table.mw_rt.id}"
#}


resource "aws_subnet" "mw_subnet1" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet1}"
  availability_zone = "${element(var.azs, 1)}"

  tags {
    Name = "MediaWikiSubnet1"
  }
}


resource "aws_subnet" "mw_subnet2" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet2}"
  availability_zone = "${element(var.azs, 2)}"
  tags {
    Name = "MediaWikiSubnet2"
  }
}

resource "aws_subnet" "mw_subnet3" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet2}"
  availability_zone = "${element(var.azs, 0)}"
  tags {
    Name = "MediaWikiSubnet3"
  }
}


resource "aws_security_group" "mw_sg" {
  name = "mw_sg"
  vpc_id = "${aws_vpc.mw_vpc.id}"
  ingress {
    from_port = 22 
    to_port  = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port = 80
    to_port  = 80
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 3306
    to_port  = 3306
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port  = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "tls_private_key" "mw_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.keyname}"
  public_key = "${tls_private_key.mw_key.public_key_openssh}"
}



# Launch the instance
resource "aws_instance" "webserver1" {
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  = "${aws_key_pair.generated_key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet1.id}" 
  associate_public_ip_address = true
  tags {
    Name = "${lookup(var.aws_tags,"webserver1")}"
    group = "web"
  }
}

resource "aws_instance" "webserver2" {
  #depends_on = ["${aws_security_group.mw_sg}"]
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  = "${aws_key_pair.generated_key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet2.id}" 
  associate_public_ip_address = true
  tags {
    Name = "${lookup(var.aws_tags,"webserver2")}"
    group = "web"
  }
}



resource "aws_instance" "dbserver" {
  #depends_on = ["${aws_security_group.mw_sg}"]
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  = "${aws_key_pair.generated_key.key_name}" 
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet2.id}"

  tags {
    Name = "${lookup(var.aws_tags,"dbserver")}"
    group = "db"
  }
}


resource "aws_elb" "mw_elb" {
  name = "MediaWikiELB"
  subnets         = ["${aws_subnet.mw_subnet1.id}", "${aws_subnet.mw_subnet2.id}"]
  security_groups = ["${aws_security_group.mw_sg.id}"]
  instances = ["${aws_instance.webserver1.id}", "${aws_instance.webserver2.id}"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

output "pem" {
        value = ["${tls_private_key.mw_key.private_key_pem}"]
}

output "address" {
  value = "${aws_elb.mw_elb.dns_name}"
}
