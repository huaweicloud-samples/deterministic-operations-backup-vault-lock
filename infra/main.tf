# ============================================================================
# 华为云备份实践 —— CBR + KMS + WORM 资源锁定
#
# 资源清单：
#   1. huaweicloud_kms_key   —— 备份加密密钥
#   2. huaweicloud_cbr_policy —— 备份策略：调度 + 保留
#   3. huaweicloud_cbr_vault  —— 备份存储库 + Vault Lock/WORM（资源锁定）
#
# 角色说明：CBR 服务委托（op_svc_cbr）在华为云由服务侧自动授权，
# 无需自建 IAM 角色，故本实践不创建 IAM 角色资源。
# ============================================================================

# ---------------------------------------------------------------------------
# 1) 加密密钥：对称 CMK，开启轮转
#    说明：华为云 KMS 密钥为区域级，无跨区域概念（默认即区域级）。
#    注意：CBR 存储库默认使用服务托管加密；将自定义 CMK 绑定到存储库在 v1.96.0
#    的 TF 资源中未暴露参数，需在控制台/API 完成（见部署文档）。
# ---------------------------------------------------------------------------
resource "huaweicloud_kms_key" "this" {
  key_alias        = var.kms_key_alias
  key_algorithm    = "AES_256"
  key_description  = "CMK for CBR backup vault encryption"
  rotation_enabled = true
  pending_days     = 30
  is_enabled       = true
}

# ---------------------------------------------------------------------------
# 2) 备份策略：每日 01:00（UTC）执行（仅调度；WORM 库策略不含保留，保留由 Vault Lock 周期承担）
# ---------------------------------------------------------------------------
resource "huaweicloud_cbr_policy" "this" {
  name      = var.policy_name
  type      = "backup"
  enabled   = true
  time_zone = var.policy_time_zone

  backup_cycle {
    # 每周七天均执行（对应 cron 的 daily）
    days             = "MO,TU,WE,TH,FR,SA,SU"
    execution_times  = [var.backup_execution_time]
  }

  # 保留策略说明：华为云 CBR 规定 WORM(locked) 存储库不允许绑定“数量型(num)保留”
  # 的备份策略，而 provider 又强制 long_term_retention 必须搭配 backup_quantity。
  # 为避免该冲突，本策略仅定义调度（每日 01:00 UTC），不在此设置任何保留；
  # 保留期由各份备份落入 WORM 存储库后的锁定周期承担，锁定天数请在控制台核对。
}

# ---------------------------------------------------------------------------
# 3) 备份存储库 + Vault Lock（资源锁定 / WORM）
#    locked=true 即开启不可变锁定（WORM）。
#    华为云锁定冷却期/最短保留天数在 v1.96.0 TF 资源中未以参数暴露，
#    锁定后请在控制台核对锁定天数（见架构适配文档）。
# ---------------------------------------------------------------------------
resource "huaweicloud_cbr_vault" "this" {
  name             = var.vault_name
  type             = var.vault_type          # server / disk —— 必填
  protection_type  = "backup"
  size             = var.vault_size          # GB —— 必填
  auto_expand      = false                   # 关闭自动扩容，避免容量意外增长
  locked           = var.vault_lock_enabled  # Vault Lock / WORM
  policy_id        = huaweicloud_cbr_policy.this.id

  tags = {
    CreatedBy     = "terraform"
    BackupTagKey  = var.backup_tag_key
  }

  # 按资源 ID 绑定到存储库（server 型存储库使用 server_id 字段；
  # includes/excludes 仅 disk/turbo 型使用，见 provider 源码 findAddServerResourcesToVault）。
  # 标签形式的批量自动选择在 v1.96.0 TF 资源中不支持，走控制台/API。
  dynamic "resources" {
    for_each = var.backup_resource_ids
    content {
      server_id = resources.value
    }
  }
}
