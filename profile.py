# CloudLab profile for Dell r7525 @ Clemson (2×V100S 32GB), Ubuntu 22.04
# - 固定 Clemson 站点
# - 指定硬件类型 r7525
# - 申请本地数据盘挂载到 /data（最佳努力 2TB）
# - 开机自动执行仓库里的 setup.sh

import geni.portal as portal
import geni.rspec.pg as pg
import geni.rspec.emulab as emulab  # 保留以便扩展高级特性

pc = portal.Context()

pc.defineParameter(
    "osImage", "OS Image",
    portal.ParameterType.STRING,
    "urn:publicid:IDN+utah.cloudlab.us+image+emulab-ops:UBUNTU22-64-STD"
)
pc.defineParameter(
    "runSetup", "Run /local/repository/setup.sh on boot",
    portal.ParameterType.BOOLEAN, True
)
pc.defineParameter(
    "requestDataStore", "Mount a local data store at /data (best effort)",
    portal.ParameterType.BOOLEAN, True
)

params = pc.bindParameters()
request = pc.makeRequestRSpec()

# 单节点
node = request.RawPC("gpu0")

# ✅ Clemson 集群
node.component_manager_id = "urn:publicid:IDN+clemson.cloudlab.us+authority+cm"

# 硬件机型：r7525（2×AMD 7542, 512GB RAM, 2×V100S 32GB）
node.hardware_type = "r7525"

# OS 镜像
node.disk_image = params.osImage

# 数据盘（最佳努力 2TB，本地块设备；CloudLab 会自动格式化并挂载）
if params.requestDataStore:
    bs = node.Blockstore("bs_data", "/data")
    bs.size = "2000GB"
    bs.best_effort = True
    bs.readonly = False

# 开机执行部署脚本
if params.runSetup:
    node.addService(pg.Execute(
        shell="bash",
        command="sudo -E bash /local/repository/setup.sh"
    ))

pc.printRequestRSpec(request)
