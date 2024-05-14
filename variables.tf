variable "Project_name" {
  type = string
  default = "roboshop"
}
variable "Environment" {
  type = string
  default = "dev"
}
variable "common_tags" {
  type = map
  default = {
    Project = "roboshop"
    Environment = "dev"
    Terraform = "true"
  }
}
variable "tags" {
  type = map

}
variable "component_security_group_id" {
  
}
variable "private_subnet_id" {

}
variable "priority" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "zone_name" {
  type = string
  default = "jasritha.tech"
}
variable "iam_instance_profile" {
  
}

variable "app_alb_listener_arn" {
  
}
variable "app_version" {
  
}