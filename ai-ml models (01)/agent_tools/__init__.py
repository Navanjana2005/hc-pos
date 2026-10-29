"""
tools/__init__.py
Auto-discovers all @tool decorated BaseTool instances from every submodule
so that agent.py can do:  import tools as agent_tools
and get all tools via inspect.getmembers().
"""

import importlib
import inspect
from langchain_core.tools import BaseTool

# _SUBMODULES = [
#     "tools.file_tools",
#     "tools.system_tools",
#     "tools.web_tools",
#     "tools.media_tools",
#     "tools.automation_tools",
#     "tools.productivity_tools",
#     "tools.image_tools",
#     "tools.document_tools",
#     "tools.data_tools",
#     "tools.security_tools",
#     "tools.developer_tools",
# ]

_SUBMODULES = [
    "agent_tools.decision_engine",
    "agent_tools.power_consumptin_prediction",
]

for _module_name in _SUBMODULES:
    try:
        _mod = importlib.import_module(_module_name)
        for _name, _obj in inspect.getmembers(_mod):
            if isinstance(_obj, BaseTool):
                globals()[_name] = _obj
    except Exception as _e:
        print(f"⚠️  Could not load module {_module_name}: {_e}")
