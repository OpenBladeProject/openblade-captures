# OpenBlade 捕获工具包

[English](README.md) | 简体中文 | [Русский](README.ru-RU.md)

本仓库包含用于研究 Razer Blade 固件接口的 Windows 工具和经过审查的协议证据。把捕获工作放在单独的仓库中，可以避免把原始证据放入产品发布包。

请从[捕获指南](docs/zh-CN/CAPTURE_GUIDE.md)开始。该指南说明如何调查尚未支持的 Blade 型号，涵盖设备清单、隔离捕获、回读、恢复、数据清理和正式准入。

已安装的 Razer 驱动程序包记录在 [`blade-driver-catalog`](https://github.com/OpenBladeProject/blade-driver-catalog/blob/main/README.zh-CN.md) 中。程序包清单和导出工作应在该仓库中进行。本仓库保存协议捕获和实际证据，用于判断某个程序包是否支持一项设备功能。

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
- `decoded`：经过清理的请求与响应固定样本、覆盖状态和分析。
- `plans`：经过审查的交互式验证计划；工具会检查其中的准确字节。
- `raw`：被 Git 忽略的本地 PCAP 文件。仓库只提交 `.gitkeep`。
- `templates`：用于新调查、带版本的起始文档。
- `tests`：不会访问实际硬件的合成离线回归测试。
- `tools`：捕获、解码、比较、清理和验证脚本。
