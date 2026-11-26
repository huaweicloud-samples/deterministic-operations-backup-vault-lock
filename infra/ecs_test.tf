# ============================================================================
# 测试用 ECS（仅用于验证 CBR 备份 + WORM 不可变，验证后可销毁）
#
# 设计约束：
#   - 不创建 EIP、不使用公网 NAT 网关；ECS 仅置于私有 VPC/子网中。
#   - 这是临时验证资源，验证完成后应 terraform destroy 释放。
# ============================================================================

# ---- 私有网络（免费，无公网）----
resource "huaweicloud_vpc" "test" {
  name = "cbr-verify-vpc"
  cidr = "192.168.100.0/24"
}

resource "huaweicloud_vpc_subnet" "test" {
  name              = "cbr-verify-subnet"
  cidr              = "192.168.100.0/24"
  gateway_ip        = "192.168.100.1"
  vpc_id            = huaweicloud_vpc.test.id
  availability_zone = "cn-north-4a"
}

resource "huaweicloud_networking_secgroup" "test" {
  name                 = "cbr-verify-sg"
  description          = "temporary secgroup for CBR verification ECS"
  delete_default_rules = false
}

# ---- 镜像（公共镜像，标准 Ubuntu 22.04 x86_64，排除 GPU/驱动变体）----
data "huaweicloud_images_image" "ubuntu" {
  # 精确锚定标准版，避免匹配到 "with Graphic driver" 等 GPU 镜像（会导致 flavor 不匹配）
  name_regex  = "^Ubuntu 22.04 server 64bit$"
  visibility  = "public"
  most_recent = true
}

# ---- 测试 ECS（通用型 x86，2vCPU/4GB，稳定兼容 Ubuntu 22.04）----
resource "huaweicloud_compute_instance_v2" "test" {
  name              = "cbr-verify-ecs"
  flavor_name       = "s6.large.2"        # 2 vCPU / 4 GB
  image_id          = data.huaweicloud_images_image.ubuntu.id
  availability_zone = "cn-north-4a"
  security_groups   = [huaweicloud_networking_secgroup.test.name]

  # 系统盘：通用型 SSD，40GB
  system_disk_type = "GPSSD"
  system_disk_size = 40

  # 登录口令（仅验证用，验证后销毁实例即可）
  admin_pass = var.test_ecs_admin_pass

  network {
    uuid = huaweicloud_vpc_subnet.test.id
  }
}

# ---- 输出 ECS ID，供回填 backup_resource_ids 绑定到存储库 ----
output "test_ecs_id" {
  description = "测试 ECS 的资源 ID，用于回填 backup_resource_ids 绑定到 CBR 存储库"
  value       = huaweicloud_compute_instance_v2.test.id
}
