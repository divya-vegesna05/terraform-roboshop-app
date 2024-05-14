locals {
  name = "${var.Project_name}-${var.Environment}"
 current_time = formatdate("YYYY-MM-DD-hh-mm",timestamp())
}