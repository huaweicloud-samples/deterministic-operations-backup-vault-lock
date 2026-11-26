# 部署指导书（华为云 CBR 不可变备份）

> 适用区域：cn-north-4（可改 `variables.tf` 中的 `region`）
> 前置：已开通云备份 CBR、密钥管理 KMS；拥有可创建存储库/策略/KMS 的账号权限。

## 1. 准备工作

1. 安装 Terraform（≥1.5.0）并配置 `huaweicloud` provider（本实践验证于 1.96.0）。
2. 配置凭据（通过环境变量注入）：

```bash
export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
export HW_SECRET_KEY="<HW_SECRET_KEY>"
export HW_REGION_NAME="cn-north-4"
```

3. 复制变量示例并填写：

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars
# 编辑 terraform.tfvars：确认 vault_size / vault_type / vault_lock_enabled 等
```

## 2. 校验与预览

```bash
cd infra
terraform init
terraform validate # 语法与 schema 校验
terraform plan # 预览将创建：1 个 KMS 密钥 + 1 个 CBR 策略 + 1 个 CBR 存储库
```

## 3. 资源运行说明

> `terraform plan` 用于预览将创建的资源；部署后资源按用量持续运行。本次涉及的主要资源为 CBR 备份存储库。

## 4. 创建资源（WORM 库需两步法）

> ⚠️ **关键约束（实测）**：华为云 CBR 规定 `locked=true` 的存储库在**创建时**不允许关联任何备份策略（API `BackupService.7461: "Create worm vault with num retention policy not allowed"`），无论策略是否含保留。因此 `main.tf` 中 `huaweicloud_cbr_vault` 的 `policy_id` 在初始创建期必须处于注释状态，建好 WORM 库后再关联。

**首次部署（从零 clone）请按两步执行：**

```bash
# 步骤 1：保持 main.tf 中 vault 的 policy_id 注释掉，先建出 WORM 库（不含策略）
terraform apply
# → 创建 KMS 密钥 + CBR 策略 + locked=true 的存储库（status=available）

# 步骤 2：取消注释 main.tf 中 vault 的 policy_id = huaweicloud_cbr_policy.this.id
# 再次 apply，terraform 对 vault 原地更新并关联策略（API 接受）
terraform apply
# → vault 关联备份策略，完成端到端配置
```

> 说明：本仓库已在 cn-north-4 实际执行过上述两步并验证通过（`policy_id` 当前为激活态）。若直接对已有状态重跑 `terraform apply` 为无变更（no-op）；仅当从零部署时才需要两步。

创建完成后记录输出：`cbr_vault_id`、`cbr_policy_id`、`kms_key_id`、`cbr_vault_locked`。

## 5. 纳管待备份资源

### 方式 A：按 ID 绑定（推荐已知资源）

在 `terraform.tfvars` 填入资源 ID 后重新 `apply`：

```hcl
backup_resource_ids = ["<resource-id-1>", "<resource-id-2>"]
```

### 方式 B：按标签批量关联（控制台/API）

1. 给待备份资源打标签，如 `Backup=True`。
2. 进入 **云备份 CBR 控制台 → 存储库 → 关联资源**，选择「按标签」筛选并关联到本存储库。
（Terraform 资源在 v1.96.0 未暴露标签选择参数，故该步骤在控制台完成。）

## 6. 验证备份

- 等待策略在 01:00 UTC 触发，或在控制台「手动执行」一次备份。
- 在 CBR 控制台确认目标资源已产生恢复点。
- 确认存储库状态为「已锁定」，且锁定期间恢复点不可删除。

## 7. 维护与销毁

- **修改保留/调度**：改 `backup_delete_after_days` / `backup_execution_time` 后 `terraform apply`。
- **销毁**：`terraform destroy` 前，**必须先在控制台解除存储库资源锁定**，否则锁定资源无法删除。
- 锁定一经开启不可逆，销毁前请务必先解锁。

## 8. 已知约束

| 约束 | 说明 |
|---|---|
| WORM 库两步法 | `locked=true` 的存储库创建时禁止关联策略（BackupService.7461），须先建库、再关联策略（见 §4） |
| 锁定天数参数 | v1.96.0 TF 未暴露冷却期/最短保留天数，锁定后在控制台核对 |
| 标签自动选择 | TF 不支持 tags 形式的选择，批量关联走控制台/API |
| 自定义 CMK 绑定 | 存储库默认服务托管加密；绑定自定义 CMK 在控制台完成 |
| 保留语义 | 因 WORM + provider 限制，备份策略只能定义调度、不能带保留；保留期由 Vault Lock 锁定周期承担（控制台核对），变量 `backup_delete_after_days` 仅作文档化标注 |
