# 为尚未支持的 Razer Blade 采集数据

[English](../../CAPTURE_GUIDE.md) | 简体中文 | [Русский](../ru-RU/CAPTURE_GUIDE.md)

本操作手册用于研究 OpenBlade 尚未支持的 Razer Blade 型号所使用的协议。它不授权任何固件写入。只有对准确型号通过本指南中的全部准入检查后，命令才能成为正式功能。记录测试过的固件版本作为来源信息；只有经过审查的准入规则明确要求时，才限制固件版本。

<a id="safety-model"></a>
## 安全要求

1. 在原生 Windows 11 上操作。使用 .NET SDK、Wireshark/tshark 和 USBPcap；供应商应用仅用于提供参照行为。
2. USBPcap 占用目标接口时，让 OpenBlade 服务保持停止。通用捕获运行器会记录并恢复服务原来的状态。
3. 每次只捕获一个操作。不得根据相近型号推断命令，也不得把多项探索性写入合并到一次捕获中。
4. 测试 setter 前，先找出并实现读取或查询操作。
5. 每次验证写入时，都要保存先前已确认的状态，显示准备进行的准确更改，要求操作人员确认，只应用一次，再查询结果并恢复保存的状态。
6. 只能通过随附的独立进程组辅助程序停止 USBPcap。不得以进程组 `0` 调用 `GenerateConsoleCtrlEvent`；这会把事件广播到父控制台，并可能终止 Codex 或 PowerShell。
7. 原始捕获文件必须保留在本地。USB 流量可能包含序列号、唯一实例路径、按键以及无关设备的数据。

<a id="toolkit"></a>
## 工具

- `tools/Get-BladeCaptureInventory.ps1` 收集不会唯一标识设备的型号、固件、Windows 和 Razer USB 标识信息。
- `tools/New-CaptureWorkspace.ps1` 创建一个被 Git 忽略的本地会话，其中包含带版本的捕获计划和操作日志。
- `tools/Invoke-InteractiveUsbPcapCapture.ps1` 在独立进程组中运行 USBPcapCMD，向指定进程组发送 Ctrl+Break 来停止它，并恢复 OpenBlade 服务原来的状态。它可以选择同一 USBPcap 根节点上的一个或多个已验证设备地址，用于范围受限的跨设备关联。
- `tools/Convert-UsbPcapToTransactions.ps1` 使用 tshark，把本地 PCAP 解码为范围受限的事务记录。
- `tools/Compare-CaptureTransactions.ps1` 比较基线捕获与单次操作捕获。对于已经验证的 90 字节和 374 字节 Razer 封装，它的语义指纹会去掉事务 ID、校验和和未使用的填充，同时保留命令与有效载荷的差异。
- `tools/New-SanitizedCaptureAnnotation.ps1` 创建可安全提交的注释框架，其中包含捕获哈希和恢复结果。
- `tools/Test-CaptureEvidence.ps1` 检查来源、清理、证据边界、捕获哈希和恢复结果。提交前使用 `-PcapPath` 验证本地捕获。只有在原始捕获有意不可用时才使用 `-SchemaOnly`。
- `tools/Test-UsbPcapShutdownSafety.ps1` 检查停止捕获时不会向父控制台广播 Ctrl+C。

下面两个脚本保留了对准确目标 RZ09-0581、BIOS 4.00 的散热底座风扇上下文调查：

- `tools/Invoke-CoolingPadFanContextCapture.ps1` 记录由 Synapse 控制的 Fixed/Auto 切换，分别覆盖同一 Synapse 进程会话中灯光帧活动、灯光关闭，以及经过验证的新 Synapse 进程会话。OpenBlade 始终保持停止，并且不发送 HID 命令。
- `tools/Analyze-CoolingPadFanContextCapture.ps1` 比较三个范围受限的标记窗口，要求准确的 Fixed/Auto 请求确认，统计灯光帧，并把进程会话证据与尚未确定的 HID 句柄实际所有权分开记录。

其他名称中包含具体型号的 `Analyze-*`、`Export-*`、`Get-*`、`Invoke-*` 和 `Start-*` 脚本，都是限定到准确设备、作为已审查证据保留的辅助程序。它们可能用于包装隔离的参照捕获、导出范围受限的固定测试样本、重复只读矩阵、执行可逆验证，或检查经过验证的供应商后端。不要把它们当作通用起点，也不要把其中的标识、接口、地址、哈希、路径、报告结构或命令字节复制到其他型号。

<a id="1-prepare-the-machine"></a>
## 1. 准备计算机

安装：

- .NET 10 SDK
- 带 tshark 的 Wireshark
- USBPcap
- 这台笔记本电脑当前使用的供应商软件，仅在捕获期间使用

进行任何实际捕获前，先验证安全停止测试：

```powershell
.\tools\Test-UsbPcapShutdownSafety.ps1
```

创建不包含唯一标识的清单：

```powershell
.\tools\Get-BladeCaptureInventory.ps1 `
  -OutputPath .\raw\my-model\inventory.json
```

检查输出。它必须包含 Razer 型号、BIOS、Windows 版本和 VID/PID，但不能包含机器序列号或完整的 PnP 实例后缀。EC 和 MCU 版本应从可信界面或之后经过验证的查询中取得，不要猜测。

如果调查涉及已安装的 Razer 驱动程序路径，请使用单独的 [`blade-driver-catalog`](https://github.com/OpenBladeProject/blade-driver-catalog) 查看程序包清单和导出说明。本仓库只保留协议与实际验证证据。驱动程序存储导出和完整设备实例报告必须保持私密。

对于准确的 Razer Laptop Cooling Pad（`1532:0F43`，USB 修订版 `0200`），单独记录其 USB 接口和 HID 报告结构：

```powershell
.\tools\Get-CoolingPadCaptureInventory.ps1 `
  -OutputPath .\raw\cooling-pad-interface-inventory.json
```

此清单以零期望访问权限打开 HID 集合，并且只调用描述符与预解析数据 API。它不发送功能报告查询或写入，也不会序列化设备接口路径、完整实例 ID、容器 ID、位置路径或序列号。经过审查的准确设备在 `MI_00` 上提供一个 91 字节功能报告集合。这证明可以使用直接用户模式 HID 传输，但不能据此确定任何命令语义。

<a id="2-create-a-local-session"></a>
## 2. 创建本地会话

```powershell
$session = .\tools\New-CaptureWorkspace.ps1 `
  -RootDirectory .\raw `
  -ModelNumber RZ09-XXXX `
  -VendorId 1532 `
  -ProductId 0000 `
  -BiosVersion 0.00 `
  -Purpose "battery charge limit query"
```

此命令创建一个被 Git 忽略的目录，其中包含：

- `capture-plan.json`：准确目标、前置条件、操作、预期观察、先前状态、回读和恢复字段；
- `operator-log.md`：时间戳和备注；
- 空的 `baseline` 与 `action` 目录。

捕获前填写完整计划。每次更改一个值时都使用新会话。

<a id="3-identify-usbpcap-root-and-device-address"></a>
## 3. 确定 USBPcap 根节点和设备地址

在管理员终端中运行 USBPcapCMD 的设备列表，并按 USB 硬件标识匹配目标。重新连接、从睡眠恢复或重新启动后，设备地址可能改变，因此每个会话都要重新确定地址。标识不明确时停止操作。不要为了省去目标识别步骤而捕获所有设备。

`-AllDevices` 只可用于描述符发现。操作捕获应使用一个 `-DeviceAddress`；如果一次操作必须关联同一 USBPcap 根节点上两个或更多明确选定的设备，则使用 `-DeviceAddresses`。不要用 `-AllDevices` 代替范围受限的多设备操作捕获。

<a id="4-capture-baseline-and-one-action"></a>
## 4. 捕获基线和单次操作

在管理员 PowerShell 中启动基线捕获：

```powershell
.\tools\Invoke-InteractiveUsbPcapCapture.ps1 `
  -UsbPcapDevice \\.\USBPcap3 `
  -DeviceAddress 2 `
  -OutputDirectory $session.BaselineDirectory
```

要在一个根节点上进行范围受限的配对捕获，请以数组形式传入已验证的临时地址。每次拔出或重新连接后都要重新确定地址：

```powershell
.\tools\Invoke-InteractiveUsbPcapCapture.ps1 `
  -UsbPcapDevice \\.\USBPcap3 `
  -DeviceAddresses 2,5 `
  -OutputDirectory $session.ActionDirectory
```

让供应商应用中的相关页面保持空闲几秒钟，然后创建运行器显示的 `capture.stop` 标记文件。在操作目录中重复捕获，只更改一个值一次，并在操作前后都留出足够的空闲时间。

运行器会：

- 使用 `CREATE_NEW_PROCESS_GROUP` 启动 USBPcapCMD；
- 记录 PID、进程组 ID、开始时间、可执行文件和输出文件所有权；
- 从独立、受保护的工作进程中，只向该非零进程组发送 `CTRL_BREAK_EVENT`；
- 确认进程正常退出且输出不为空；
- 仅当 OpenBlade 服务在捕获前处于运行状态时才恢复它。

交互式运行器不会自动选择强制终止。如果正常停止失败，操作人员可以针对保留的所有权会话明确运行 `Stop-UsbPcapCapture.ps1 -ForceFallback`。强制终止可能丢失缓冲区中的数据包，必须在注释中披露。

<a id="5-decode-and-compare"></a>
## 5. 解码并比较

```powershell
.\tools\Convert-UsbPcapToTransactions.ps1 `
  -PcapPath $session.BaselinePcap `
  -OutputPath (Join-Path $session.Root "baseline-transactions.json")

.\tools\Convert-UsbPcapToTransactions.ps1 `
  -PcapPath $session.ActionPcap `
  -OutputPath (Join-Path $session.Root "action-transactions.json")

.\tools\Compare-CaptureTransactions.ps1 `
  -BaselinePath (Join-Path $session.Root "baseline-transactions.json") `
  -ActionPath (Join-Path $session.Root "action-transactions.json") `
  -OutputPath (Join-Path $session.Root "comparison.json")
```

解码器保留帧编号、相对时间、方向、端点、设置字段、范围受限的十六进制有效载荷和长度。在审查并清理前，把输出视为原始数据。有效载荷存在差异只能说明它是候选项，不能据此定义命令。比较器可识别带或不带报告 ID 前缀、校验和有效的 90 字节与 374 字节 Razer 封装。它忽略事务 ID、校验和、保留字节和未使用的填充，但保留状态、报告 ID、命令类别/ID、有效载荷长度和语义有效载荷。未知或格式错误的有效载荷会退回到完整有效载荷的精确比较。

部分成功的 USBPcap 控制传输完成帧包含响应正文，但 Wireshark 的所有语义有效载荷字段都为空。解码器会仅针对这些 IN 帧再次运行严格筛选的 `tshark -T json -x`，去掉声明的 USBPcap 伪标头，并把范围受限的正文标记为 `UsbPcapFrameData`。完整原始帧和 IRP 元数据不会被序列化。在认定命令没有 ACK 或查询响应前，必须先执行此回退步骤。

关联候选项时应使用：

- 准确的操作时间戳；
- 同一值的重复捕获；
- 同一控件中的另一个值；
- 没有执行操作的负对照捕获；
- 对应的读取或查询流量。

确定报告封装、事务 ID、命令类别/ID、有效载荷长度、校验和、响应状态，以及编码数值的字节。去掉无关的中断输入和周期遥测。

<a id="6-build-a-query-first-fixture"></a>
## 6. 先建立查询固定样本

可以安全提交的查询固定样本应记录：

- 已知的型号、VID、PID、BIOS、EC 和 MCU；
- 接口/集合和报告 ID；
- 经过清理的请求与预期响应；
- 有效载荷边界和校验和解释；
- 事务关联和可接受状态；
- 捕获哈希和解码器版本；
- 相邻流量中的负面证据。

在类型化的开发者命令中实现查询。命令必须验证准确设备标识，拒绝格式错误或不匹配的响应，设置超时，并且不能提供任意有效载荷选项。

在以下条件下重复运行查询：

- 服务重新启动；
- 设备重新连接；
- 睡眠和恢复；
- 适用时分别使用交流电、USB-C 和电池；
- 供应商软件正在运行和已经停止。

查询失败时，功能必须变为不可用，并且不能写入设备。

<a id="7-validate-a-setter"></a>
## 7. 验证 setter

不要用通用捕获脚本重放字节。在 `plans` 下添加经过审查的类型化验证计划，在开发者工具中以哈希限制其准确字节，并在执行前显示计划。

交互式运行器必须：

1. 验证准确型号、PID 和允许的固件；
2. 查询并显示先前状态；
3. 显示准确的一项数值更改和恢复值；
4. 要求确认；
5. 应用一个值；
6. 查询回读并进行比较；
7. 在 `finally` 中恢复先前值；
8. 查询恢复后的值并进行比较；
9. 输出范围受限且不含原始流量的结果。

没有独立回读时，setter 不能确认固件的当前状态。OpenBlade 可以保留用户需要的配置；对于灯光，可以在用户启用的覆盖策略允许且重新通过安全检查时重新应用设置。结果不明确的写入不得重放。仅靠目视确认不能替代恢复。

<a id="8-coverage-matrix"></a>
## 8. 覆盖矩阵

只调查目标设备具备的控件，但必须把每一行明确标为支持、不存在、仅软件或尚未调查。

为目标复制 `templates/device-coverage.template.json`。其 schema 2 嵌套矩阵分别跟踪每种电源上下文、USB-C 功率类别、灯光变体、颜色/持续时间/方向/区域组、生命周期事件、冲突行为和故障模式。在捕获、查询验证、setter 验证和正式准入依次提供证据前，让各项功能保持 `NotInvestigated`。目标缺少的功能应标记为 `Absent`；不要删除该行，也不要把多个变体合并成一个状态。

| 范围 | 最少捕获内容 |
| --- | --- |
| 标识 | 描述符、型号、BIOS、EC、MCU、相关接口 |
| 性能 | 每个交流电/USB-C/电池预设、自定义级别、回读 |
| 风扇 | Auto、固定范围端点和步进、最大值、手动写入、RPM 查询 |
| 电池 | 关闭保护、每个公开的限制值、临时充满、查询 |
| 键盘灯光 | Off、亮度、每种效果、所有颜色/持续时间/方向/区域 |
| 徽标灯光 | 每种模式和 getter |
| 键盘行为 | Fn 优先、Gaming mode、启动动画、设备模式 |
| 特殊键 | 每个 Fn 层或专用硬件操作的原始报告 |
| 显示 | Windows 可见模式、DRR、HDR、颜色配置文件行为 |
| 生命周期 | 冷启动、登录、服务重新启动、睡眠/恢复、重新连接 |
| 电源 | 完整交流供电、每个支持的 USB-C 类别、电池、切换 |
| 冲突 | 供应商控制器存在、外部更改、明确重新取得控制权 |
| 故障 | 超时、格式错误的响应、错误事务、不支持的 PID |

如果效果或控件有多个变体，应捕获每个变体，不要假定它只是一个位标志。对于由主机渲染的效果，应同时捕获设置命令和足够的帧流量，以确定矩阵格式与节奏。

<a id="model-specific-helpers-and-evidence-ledgers"></a>
### 型号专用辅助程序和证据记录

以型号命名的脚本固定到其已审查会话的设备标识、接口、控制器所有权、预期文件和安全边界。重新运行前，检查参数和保留的证据，确认准确型号和允许的固件，并使用新的、被 Git 忽略的输出目录。不要放宽硬编码的标识、地址、路径、签名或哈希检查，使辅助程序能够在另一台计算机上运行。

保留的辅助程序通常只负责以下一项工作：

1. 参照捕获包装器隔离 OpenBlade，解析 USBPcap 地址，把 PCAP 保留在本地，并保存操作和捕获状态文件。
2. 分析器或导出器把本地捕获转换为范围受限、经过清理的固定测试样本，同时保持标识、时序、校验和与报告结构检查不变。
3. 只读矩阵在操作人员确认的电源或生命周期状态下重复类型化查询，同时防止竞争性读取，并恢复它临时隔离的所有服务。
4. 可逆验证器保存准确设备的状态，应用一个范围受限的值，独立读取结果，然后恢复。应用被拒绝或成功恢复仍可能只构成负面证据，不能据此准入 setter。
5. 所有权或生命周期检查器可以确定哪个经过签名且固定哈希的供应商组件拥有后端。所有权、getter 超时或静态分析都不能授权内核驱动程序、供应商依赖项或 setter。

把 `decoded/*-device-coverage.json` 作为准确型号和固件范围的权威状态矩阵。对应的 `decoded/*-evidence.json` 可以概述已准入的传输、控件、生命周期行为和故障处理。其他已解码固定样本可保存范围受限的报告、效果参照、按键映射和验证结果。对应注释记录来源、隔离、恢复、负面结果和限制。

每个覆盖项都要独立推进。一个基础控件或效果通过验证，并不自动验证其参数、getter、回读、电源上下文或生命周期。部分实际报告可以区分而其他报告不能区分时，应保留这部分输入证据。已安装应用的界面检查和回归验收只证明产品行为，不能作为固件命令或设备回读的证据。

<a id="9-sanitize-and-validate"></a>
## 9. 清理并验证

创建注释框架：

```powershell
.\tools\New-SanitizedCaptureAnnotation.ps1 `
  -PlanPath (Join-Path $session.Root "capture-plan.json") `
  -StatePath (Join-Path $session.ActionDirectory "capture.state.json") `
  -PcapPath $session.ActionPcap `
  -OutputPath .\annotations\YYYY-MM-DD-action.json
```

用经过审查且范围受限的证据替换占位内容。不要粘贴完整的有效载荷流。把 `action.kind` 设为 `ReadOnlyQuery`、`SettingChange`、`Observation` 或 `NegativeControl`；每个 `SettingChange` 都需要成功的先前状态、应用、回读、恢复和恢复后回读结果。来源角色使用 `OracleCapture`、`ReadOnlyQueryCapture`、`NegativeCapture`、`ExactDeviceInteractiveValidation` 或 `OpenBladeTypedValidation`，并包含控制器名称和版本。每个 `sanitizedEvidence` 项都需要简短的 `kind`、便于阅读的 `summary`，以及重现协议结论所需的最少字段。然后运行：

```powershell
.\tools\Test-CaptureEvidence.ps1 `
  -AnnotationPath .\annotations\YYYY-MM-DD-action.json `
  -PcapPath $session.ActionPcap
```

验证器会拒绝以下内容：缺少来源；没有披露的空捕获或全设备捕获；没有披露的强制停止；缺少恢复结果；本地路径；类似序列号的值；无边界证据；原始捕获文件扩展名。`-PcapPath` 是提交前门槛：它会把已记录的 SHA-256 和字节长度与本地原始捕获进行比较。审查已经提交、且其 PCAP 按设计未被 Git 跟踪的注释时，应明确使用 `-SchemaOnly` 模式。该模式验证 schema 和清理结果，但会报告 PCAP 哈希未经过独立验证。

更改 schema、比较、清理、覆盖矩阵或其他工具行为后，运行离线回归：

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File .\tests\Run-All.ps1
```

自动化中使用 `-NonInteractive`。其中一个回归测试会故意省略验证器要求的模式，以证明它会安全失败；否则，交互式 PowerShell 主机会等待必填参数提示。

<a id="10-production-admission"></a>
## 10. 正式准入

只有下面每项检查都独立通过后，功能才可加入 OpenBlade 正式支持表：

- 已记录准确型号/PID 范围、测试过的固件，以及任何明确的固件限制；
- 已提交至少一个经过清理的参照捕获；
- 请求和响应可以确定性解码；
- 校验和、边界、事务 ID、状态和超时均已验证；
- 类型化查询无需供应商进程即可工作；
- 类型化 setter 应用请求的值；
- 回读与请求相符；
- 先前状态成功恢复，并由回读确认；
- 明确准入规则排除的不支持设备和固件产生零次写入；
- 冲突策略产生预期的零写入或明确重新取得控制权结果；
- 生命周期和电源状态测试通过；
- 单元测试使用已提交的固定测试样本。

这些检查通过前，只能把命令保留为捕获证据或仅供开发者使用的探测功能。
