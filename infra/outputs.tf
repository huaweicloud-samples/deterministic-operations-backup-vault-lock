output "kms_key_id" {
  description = "备份加密 CMK ID"
  value       = huaweicloud_kms_key.this.id
}

output "cbr_policy_id" {
  description = "CBR 备份策略 ID"
  value       = huaweicloud_cbr_policy.this.id
}

output "cbr_vault_id" {
  description = "CBR 备份存储库 ID"
  value       = huaweicloud_cbr_vault.this.id
}

output "cbr_vault_name" {
  description = "CBR 备份存储库名称"
  value       = huaweicloud_cbr_vault.this.name
}

output "cbr_vault_locked" {
  description = "存储库是否已锁定（Vault Lock / WORM）"
  value       = huaweicloud_cbr_vault.this.locked
}
