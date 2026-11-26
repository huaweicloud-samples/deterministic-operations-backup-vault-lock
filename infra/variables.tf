# ============================================================================
# 变量定义
# 关键字段（vault_size、vault_type）一律显式写死，便于 apply 前核对配置。
# ============================================================================

variable "region" {
  type        = string
  default     = "cn-north-4"
  description = "华为云目标区域。默认 cn-north-4。"
}

# ---- 备份存储库（CBR Vault）----
variable "vault_name" {
  type        = string
  default     = "demo-cbr-backup-vault"
  description  = "CBR 备份存储库名称。"
}

# 必填：server=云服务器备份 / disk=云硬盘备份。
# 显式写死，避免交给数据源下标或 provider 默认值。
variable "vault_type" {
  type        = string
  default     = "server"
  description  = "CBR 存储库类型：server(云服务器备份) / disk(云硬盘备份) / turbo / vmware 等。必填。"
}

# 必填：存储库容量（GB）。显式写死。
variable "vault_size" {
  type        = number
  default     = 200
  description  = "CBR 存储库容量（GB）。"
}

# Vault Lock / WORM（资源锁定）。默认开启。
# 注意：一旦锁定即不可变，且华为云锁定冷却期/最短保留期在 v1.96.0 的 TF 资源中
# 不以参数暴露（见架构适配文档），锁定后须在控制台核对锁定天数。
variable "vault_lock_enabled" {
  type        = bool
  default     = true
  description  = "是否启用 CBR 存储库资源锁定（WORM）。"
}

# ---- 备份策略（CBR Policy）----
variable "policy_name" {
  type        = string
  default     = "demo-cbr-backup-policy"
  description  = "CBR 备份策略名称。"
}

# 备份策略默认按 UTC 解释（与官方模板的 cron 语义对齐）。
variable "policy_time_zone" {
  type        = string
  default     = "UTC+00:00"
  description  = "备份策略时区。默认 UTC+00:00，对齐 cron(0 1 * * ? *) 的 UTC 01:00。"
}

variable "backup_execution_time" {
  type        = string
  default     = "01:00"
  description  = "每日执行时间 HH:MM（华为云 CBR 策略调度字段）。"
}

# 备份保留天数（文档化标注）。
# 注意（实测调整）：WORM（locked）存储库禁止关联带保留的策略，且 provider 强制
# long_term_retention 必须搭配 backup_quantity；二者叠加使 WORM 库的策略只能定义调度、
# 不能带保留。因此本变量仅作文档化标注，实际保留期由
# Vault Lock 锁定周期承担，锁定天数请在控制台核对。详见架构适配文档 §4。
variable "backup_delete_after_days" {
  type        = number
  default     = 45
  description  = "保留策略的文档化标注；WORM 库策略不含保留，实际保留由 Vault Lock 周期承担。"
}

# ---- 加密密钥（KMS）----
variable "kms_key_alias" {
  type        = string
  default     = "demo-cbr-backup-kms"
  description  = "KMS CMK 别名。"
}

# ---- 资源选择（标签）----
# 华为云 CBR 在 v1.96.0 的 TF 资源中不支持 tags 形式的自动选择，
# 资源绑定通过存储库 resources 块（按资源 ID）或控制台/API 完成。
# 下面两个变量用于文档化标注「应给待备份资源打的标签」，
# backup_resource_ids 用于把真实资源 ID 绑定到存储库。
variable "backup_tag_key" {
  type        = string
  default     = "Backup"
  description  = "待备份资源应打的标签 Key。"
}

variable "backup_tag_value" {
  type        = string
  default     = "True"
  description  = "待备份资源应打的标签 Value。"
}

variable "backup_resource_ids" {
  type        = list(string)
  default     = []
  description  = "需要纳入本存储库备份的资源 ID 列表（按 ID 绑定）。留空则只建框架、不绑定资源；标签形式的批量选择请参考部署文档通过控制台/API 完成。"
}

# 仅用于「测试 ECS」的登录口令（验证 CBR 备份用，验证后销毁实例即可）。
# 非云账号凭据，请勿复用为生产口令。
variable "test_ecs_admin_pass" {
  type        = string
  description  = "测试 ECS 的临时登录口令（满足复杂度：大小写+数字+特殊字符），需显式提供；验证后资源即销毁。"
  sensitive   = true
}
