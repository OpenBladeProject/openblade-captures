# OpenBlade 捕获工具包

[English](README.md) | 简体中文 | [Русский](README.ru-RU.md)

本仓库包含用于研究 Razer Blade 固件接口的 Windows 工具和经过审查的协议证据。捕获工作单独存放，避免原始证据混入产品发布包。

请先阅读[捕获指南](docs/zh-CN/CAPTURE_GUIDE.md)，了解如何调查尚未支持的 Blade 型号：整理设备清单、隔离捕获、回读和恢复状态、清理数据，最后完成正式准入检查。

已安装的 Razer 驱动程序包记录在 [`blade-driver-catalog`](https://github.com/OpenBladeProject/blade-driver-catalog/blob/main/README.zh-CN.md) 中。查看驱动包清单或导出驱动包，请使用该仓库。本仓库保存协议捕获和实机证据，用于判断某个程序包是否支持一项设备功能。

OpenBlade 的一般文档位于 [`OpenBladeProject/openblade-docs`](https://github.com/OpenBladeProject/openblade-docs/blob/main/README.zh-CN.md)。

<a id="before-you-start"></a>
## 开始前

- 原始 PCAP 和 PCAPNG 文件只能保存在本地。
- 不得提交序列号、用户名、本地路径、设备实例后缀或未经审查的有效载荷流。
- 每次只捕获一个操作；先调查查询，再调查写入。
- 没有针对准确目标型号完成捕获和验证时，不得复用其他 Blade 型号的命令。

[捕获指南](docs/zh-CN/CAPTURE_GUIDE.md)包含完整的安全规则、命令、工具参考、证据工作流程和准入检查表。

<a id="repository-layout"></a>
## 仓库结构

- `annotations`：操作、来源、时间和安全结果。
- `decoded`：经过清理的请求与响应测试样本、覆盖状态和分析。
- `plans`：经过审查的交互式验证计划；工具会逐字节核验计划内容。
- `raw`：被 Git 忽略的本地 PCAP 文件。仓库只提交 `.gitkeep`。
- `templates`：带版本信息的调查文档模板。
- `tests`：不会访问实际硬件的合成离线回归测试。
- `tools`：捕获、解码、比较、清理和验证脚本。
