terraform {
  required_version = ">= 1.5.0"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "1.96.0"
    }
  }
}

# 区域固定为 cn-north-4（默认部署区域）。如需切换区域，仅改此变量即可。
provider "huaweicloud" {
  region = var.region
}
