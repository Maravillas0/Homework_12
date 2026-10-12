# 2026-10-11T10:23:38.817202300
import vitis

client = vitis.create_client()
client.set_workspace(path="DMA")

platform = client.get_component(name="platform2")
status = platform.build()

status = platform.build()

comp = client.get_component(name="app_component")
comp.build()

status = platform.build()

comp.build()

