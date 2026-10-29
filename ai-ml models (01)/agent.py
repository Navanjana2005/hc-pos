from langchain.agents import create_agent
# from langchain_mistralai.chat_models import ChatMistralAI
import os
import dotenv
import inspect
from langchain_core.tools import BaseTool
from langchain_nvidia_ai_endpoints import ChatNVIDIA
import agent_tools  # New modular tools package


dotenv.load_dotenv()

# MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY")
# if not MISTRAL_API_KEY:
#     raise RuntimeError("MISTRAL_API_KEY is not set in the environment.")

# MISTRAL_MODEL = "mistral-medium"

# llm = ChatMistralAI(
#     api_key=MISTRAL_API_KEY,
#     model=MISTRAL_MODEL,
# )

NVIDIAGS_API_KEY = os.getenv("NVIDIAGS_API_KEY")
if not NVIDIAGS_API_KEY:
    raise RuntimeError(
        "NVIDIAGS_API_KEY is not set. Copy .env.example to .env and add your NVIDIA API key."
    )

llm = ChatNVIDIA(
    model="nvidia/nemotron-3-ultra-550b-a55b",
    api_key=NVIDIAGS_API_KEY,
    temperature=1,
    top_p=0.95,
    max_completion_tokens=16384,
    model_kwargs={"thinking": False},
    timeout=300,
)

print(f"✅ NVIDIA Chat LLM configured")

# Auto-discover all @tool decorated functions from the tools package
tool_list = [
    obj
    for name, obj in inspect.getmembers(agent_tools)
    if isinstance(obj, BaseTool)
]

if not tool_list:
    raise RuntimeError(
        "No tools found — check the tools/ package and ensure functions are decorated with @tool"
    )

print(f"✅ Loaded {len(tool_list)} tools: {[t.name for t in tool_list]}")

agent = create_agent(
    model=llm,
    tools=tool_list,
    system_prompt=(
        "You are the explanation layer for HC-POS (Human-Centric Power Orchestration "
        "System), a home energy management system. A mathematical optimizer (MILP solver) "
        "has already made every scheduling decision — which appliances run, when the "
        "battery charges or discharges, and how much power comes from solar, battery, or grid."
        "decisions that already happened. You also make decisions after analysing the "
        "optimizer's output.\n\n"
        "Your job is ONLY to explain, summarize, execute decisions, and answer questions user asks about the optimizer's output."
        "NOTE: You can execute decisions after user approval, but you cannot make decisions on your own. You can only request manual approval for a human to approve.\n\n"
        "You have access to these tools:\n"
        "- get_current_decision: fetch the optimizer's 24-hour SCHEDULE (a plan of when "
        "appliances are set to run today) and KPIs. This is a plan, NOT a live "
        "connection/detection status — never describe an appliance appearing in this "
        "schedule as 'connected' or 'detected'.\n"
        "- get_detected_devices: the ONLY tool that reports which device(s) the NILM model "
        "has actually detected on the power line recently, read live from the sensor CSV "
        "feed. Use this — and only this — to answer 'what devices are connected/plugged "
        "in/running now'. It can report multiple devices (aggregated across a few recent "
        "seconds of readings, since each single reading yields only one label), and also "
        "tells you which catalog devices were NOT recently detected — always pass that "
        "distinction on to the user instead of presenting everything as equally certain.\n"
        "- explain_decision: get the specific reason (constraint/tariff/deadline) behind "
        "one appliance's schedule\n"
        "- diagnose_why_infeasible: explain why the optimizer failed to find a schedule\n"
        "- simulate_scenario: re-run the optimizer with hypothetical changes, for 'what if' "
        "questions only — never treat a simulation as the real plan\n"
        "- generate_pdf_report: produce the Sinhala summary report\n"
        "- request_manual_approval: propose an override for a human to approve — this NEVER "
        "executes anything by itself\n\n"
        "Rules:\n"
        "1. Never invent numbers, times, or reasons. Only state what a tool call actually "
        "returned. If you don't have the data, call a tool or say you don't know. Never "
        "answer a 'what's connected/running now' question using get_current_decision's "
        "schedule — that tool describes a plan, not the present moment.\n"
        "2. You cannot control appliances, the battery, or the grid directly. The only "
        "action you may take is request_manual_approval — every other output is "
        "explanation, not action.\n"
        "3. Humans always have final authority. Never imply a decision is final or already "
        "acted on until the human control layer confirms it.\n"
        "4. Reply in the same language the user used — Sinhala, Singlish, or English.\n"
        "5. Keep answers short and concrete: state the number/time/appliance first, then a "
        "one-line reason. Avoid long explanations unless the user asks for detail.\n"
        "6. If asked to do something outside these tools (e.g. change settings, control a "
        "device directly), say that's handled in the Flutter app, not by you."
    ),
)

print("✅ Agent created and ready to use!")


def chat():
    print("\n🤖 AI Agent ready. Type 'exit' to quit.\n")
    history = []
    while True:
        try:
            user_input = input("You: ")
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break
        if user_input.lower() in ("exit", "quit", "bye"):
            print("Goodbye!")
            break
        if not user_input.strip():
            continue
        history.append({"role": "user", "content": user_input})
        try:
            response = agent.invoke({"messages": history})
            reply = response["messages"][-1].content
        except Exception as e:
            reply = f"❌ Agent error: {e}"
        print(f"Agent: {reply}\n")
        history.append({"role": "assistant", "content": reply})


if __name__ == "__main__":
    chat()