# src/

本仓库为**纯 IaC（基础设施即代码）**实践，仅包含 基础设施编排 模板
不含有任何应用运行代码（无函数 / 无前端）。因此本目录下**不包含 FunctionGraph 函数或前端代码**。

本实践以 Terraform 实现，全部逻辑位于 `../infra/`：

- `provider.tf` —— provider 与区域配置
- `variables.tf` —— 全部可配置参数
- `main.tf` —— KMS 密钥 / CBR 备份策略 / CBR 备份存储库（含 Vault Lock）
- `outputs.tf` —— 关键资源 ID 输出
- `terraform.tfvars.example` —— 变量示例

如需把真实业务资源纳入备份，请把资源 ID 填入 `backup_resource_ids`
或按 `docs/deployment-guide.md` 通过控制台/API 以标签批量关联。
