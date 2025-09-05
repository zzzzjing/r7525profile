# -*- coding: utf-8 -*-
# CloudLab profile: Dell r7525 @ Clemson (2x V100S 32GB), Ubuntu 22.04

import geni.portal as portal
import geni.rspec.pg as pg
import geni.rspec.emulab as emulab  # kept for future extensions

pc = portal.Context()

# Parameters
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
    "requestDataStore",
    "Create and mount a local data store at /data (best effort).",
    portal.ParameterType.BOOLEAN, True
)

params = pc.bindParameters()
request = pc.makeRequestRSpec()

# Single node
node = request.RawPC("gpu0")

# Clemson cluster
node.component_manager_id = "urn:publicid:IDN+clemson.cloudlab.us+authority+cm"

# Hardware type: r7525 (2x AMD 7542, 512GB RAM, 2x V100S 32GB)
node.hardware_type = "r7525"

# OS image
node.disk_image = params.osImage

# Data store (best-effort ~2TB; CloudLab handles the mount)
if params.requestDataStore:
    bs = node.Blockstore("bs_data", "/data")
    bs.size = "2000GB"
    bs.best_effort = True
    bs.readonly = False

# Run setup script on boot
if params.runSetup:
    node.addService(pg.Execute(
        shell="bash",
        command="sudo -E bash /local/repository/setup.sh"
    ))

pc.printRequestRSpec(request)
