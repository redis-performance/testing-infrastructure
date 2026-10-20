module "placement" {
  source        = "../_modules/subnet_placement"
  placement_key = var.setup_name
}
