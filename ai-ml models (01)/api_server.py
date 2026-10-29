"""
api_server.py
=============
FastAPI HTTP server wrapping the HC-POS LangChain agent and MILP optimizer.

Start with:
    uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload

Endpoints:
    GET  /health            — liveness check
    POST /chat              — send a message to the Genesis AI agent
    POST /run-optimizer     — run the MILP optimizer and persist results to Supabase
"""

import os
import logging
import inspect
import threading
import time
from datetime import datetime, timezone
import dotenv

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional

dotenv.load_dotenv()

import sys

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)
logger = logging.getLogger("hc_pos.api")

# ---------------------------------------------------------------------------
# Lazy-initialise the heavy objects once on first request, not at import time,
# so the server starts fast and models load in the background.
# ---------------------------------------------------------------------------
_agent = None
_tool_list = None


def _init_agent():
    global _agent, _tool_list
    if _agent is not None:
        return _agent

    from langchain.agents import create_agent
    from langchain_mistralai.chat_models import ChatMistralAI
    from langchain_nvidia_ai_endpoints import ChatNVIDIA
    from langchain_core.tools import BaseTool
    import agent_tools

    # MISTRAL_API_KEY = os.getenv("MISTRAL_API_KEY")
    # if not MISTRAL_API_KEY:
    #     raise RuntimeError("MISTRAL_API_KEY not set in .env")

    NVIDIAGS_API_KEY = os.getenv("NVIDIAGS_API_KEY")
    if not NVIDIAGS_API_KEY:
        raise RuntimeError("NVIDIAGS_API_KEY not set in .env")

    llm = ChatNVIDIA(
        model="nvidia/nemotron-3-ultra-550b-a55b",
        api_key=NVIDIAGS_API_KEY,
        temperature=1,
        top_p=0.95,
        max_completion_tokens=16384,
        model_kwargs={"thinking": False},
        timeout=300,
    )

    _tool_list = [
        obj for _, obj in inspect.getmembers(agent_tools)
        if isinstance(obj, BaseTool)
    ]
    if not _tool_list:
        raise RuntimeError("No tools found in agent_tools package.")

    _agent = create_agent(
        model=llm,
        tools=_tool_list,
        system_prompt=(
            "You are the explanation layer for HC-POS (Human-Centric Power Orchestration "
            "System), a home energy management system. A mathematical optimizer (MILP solver) "
            "calculates optimal scheduling decisions every 5 minutes.\n\n"
            "Your job is to explain, summarize, and answer questions the user asks about the system state, "
            "power schedule, forecasts, and live device detections.\n\n"
            "You have access to these tools:\n"
            "- get_detected_devices: the ONLY tool that reports which device(s) the 1D-CNN NILM model "
            "has actually detected on the power line from live sensor data. Use this tool whenever the user "
            "asks 'what devices are currently connected/plugged in/running now'.\n"
            "- get_current_decision: fetch the optimizer's 24-hour SCHEDULE and planned run-times. This is a "
            "future plan, not a live detection status.\n"
            "- explain_decision: explain the reasoning behind an appliance's scheduled start time.\n"
            "- diagnose_why_infeasible: explain why the optimizer failed to find a schedule if infeasible.\n"
            "- simulate_scenario: test hypothetical 'what if' scenarios.\n"
            "- generate_pdf_report: generate a summary PDF report.\n"
            "- request_manual_approval: request human user approval before executing an override.\n"
            "- predict_next_24_hours: get LSTM solar generation and household consumption forecasts.\n\n"
            "Rules:\n"
            "1. Never invent numbers, times, or device names. Only report what tools return.\n"
            "2. For questions about currently active/connected devices, ALWAYS call get_detected_devices.\n"
            "3. Reply in the same language the user used — Sinhala, Singlish, or English.\n"
            "4. Keep answers short, clear, and direct."
        ),
    )
    logger.info("Agent initialised with %d tools.", len(_tool_list))
    return _agent


# ---------------------------------------------------------------------------
# Pydantic request/response models
# ---------------------------------------------------------------------------

class ChatMessage(BaseModel):
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str


class ChatRequest(BaseModel):
    message: str
    history: List[ChatMessage] = []


class ChatResponse(BaseModel):
    reply: str
    tool_calls_made: List[str] = []


class OptimizerResponse(BaseModel):
    status: str
    summary: dict = {}
    decisions_written: int = 0
    forecasts_written: int = 0
    message: Optional[str] = None


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Background 5-minute optimizer loop
# ---------------------------------------------------------------------------
_latest_optimization: dict = {}
_optimization_lock = threading.Lock()


def execute_optimization_cycle(user_id: Optional[str] = None) -> dict:
    """
    Executes the full pipeline:
    1. Read live sensor CSV data & detect devices via 1D-CNN NILM
    2. Generate LSTM solar and consumption forecasts
    3. Run the MILP Decision Engine
    4. Persist updated decisions and forecasts to Supabase
    5. Cache the latest result for instant query access
    """
    global _latest_optimization
    try:
        from agent_tools.decision_engine import (
            build_live_inputs, solve, build_agent_payload,
            write_decisions_to_supabase, write_forecasts_to_supabase,
        )

        logger.info("Executing 5-minute optimization cycle...")
        inputs = build_live_inputs()
        status, schedule, kpis = solve(inputs)

        if status != "Optimal":
            logger.warning("Optimization cycle returned non-optimal status: %s", status)
            return {"status": status, "message": "Infeasible or non-optimal"}

        payload = build_agent_payload(status, schedule, kpis, inputs)

        decisions_written = 0
        try:
            write_decisions_to_supabase(kpis, inputs, user_id=user_id)
            decisions_written = len(
                [v for v in kpis.get("appliance_run_times", {}).values() if v is not None]
            )
        except Exception as exc:
            logger.warning("Decision write-back skipped in background cycle: %s", exc)

        forecasts_written = 0
        try:
            write_forecasts_to_supabase(
                solar=inputs.solar_forecast,
                consumption=inputs.consumption_forecast,
                start_hour=inputs.start_hour,
                user_id=user_id,
            )
            forecasts_written = len(inputs.solar_forecast)
        except Exception as exc:
            logger.warning("Forecast write-back skipped in background cycle: %s", exc)

        result = {
            "status": status,
            "summary": payload.get("summary", {}),
            "decisions_written": decisions_written,
            "forecasts_written": forecasts_written,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        with _optimization_lock:
            _latest_optimization = result
        logger.info(
            "5-minute optimization cycle completed successfully. Decs=%d, Fore=%d, Cost=Rs %.2f",
            decisions_written, forecasts_written, kpis.get("total_cost", 0.0)
        )
        return result
    except Exception as exc:
        logger.error("Error in background optimization cycle: %s", exc)
        return {"status": "Error", "message": str(exc)}


def _periodic_optimizer_worker():
    """Runs every 5 minutes (300 seconds) in a daemon thread."""
    logger.info("Started 5-minute periodic optimizer background worker.")
    # Initial pause to let server finish starting up and sensor stream populate
    time.sleep(10)
    while True:
        try:
            execute_optimization_cycle()
        except Exception as exc:
            logger.error("Periodic optimizer worker unexpected exception: %s", exc)
        # Sleep for 5 minutes (300 seconds)
        time.sleep(300)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("HC-POS API server starting up...")
    def _warmup():
        try:
            logger.info("Pre-warming AI agent and ML models in background...")
            _init_agent()
            logger.info("AI agent and ML models pre-warmed and ready.")
        except Exception as e:
            logger.warning("Pre-warmup warning: %s", e)

    threading.Thread(target=_warmup, daemon=True).start()
    threading.Thread(target=_periodic_optimizer_worker, daemon=True).start()
    yield
    logger.info("HC-POS API server shutting down.")


app = FastAPI(
    title="HC-POS Genesis AI API",
    description="REST interface for the HC-POS LangChain agent and MILP optimizer",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # tighten this to your Flutter app domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["Meta"])
async def health():
    """Liveness check — confirms the server is running."""
    return {"status": "ok", "service": "HC-POS Genesis AI"}


@app.post("/chat", response_model=ChatResponse, tags=["Agent"])
async def chat(req: ChatRequest):
    """
    Send a message to the Genesis AI agent and receive a reply.

    The Flutter app sends the full conversation history with each request
    so the agent has context.  The server is stateless.
    """
    try:
        agent = _init_agent()
    except Exception as exc:
        logger.error("Agent init failed: %s", exc)
        raise HTTPException(status_code=503, detail=f"Agent unavailable: {exc}")

    history = [{"role": m.role, "content": m.content} for m in req.history]
    history.append({"role": "user", "content": req.message})

    try:
        response = agent.invoke({"messages": history})
        reply = response["messages"][-1].content

        # Collect tool names used in this turn (for debug display in Flutter)
        tool_calls_made = []
        for msg in response.get("messages", []):
            if hasattr(msg, "tool_calls") and msg.tool_calls:
                for tc in msg.tool_calls:
                    if isinstance(tc, dict):
                        tool_calls_made.append(tc.get("name", ""))
                    else:
                        tool_calls_made.append(getattr(tc, "name", ""))

        return ChatResponse(reply=reply, tool_calls_made=tool_calls_made)

    except Exception as exc:
        logger.error("Agent invoke error: %s", exc)
        raise HTTPException(status_code=500, detail=f"Agent error: {exc}")


@app.post("/run-optimizer", response_model=OptimizerResponse, tags=["Optimizer"])
async def run_optimizer(user_id: Optional[str] = None):
    """
    Run the MILP optimizer with live ML forecasts, then persist the results
    (decisions + forecasts) to Supabase.

    Pass ?user_id=<supabase-auth-uuid> to associate the rows with a user.
    If omitted, the service_role key bypasses RLS so rows are still written.
    """
    try:
        res = execute_optimization_cycle(user_id=user_id)
        if res.get("status") != "Optimal":
            return OptimizerResponse(
                status=res.get("status", "Failed"),
                message=res.get("message", "Optimizer did not find a feasible schedule."),
            )
        return OptimizerResponse(
            status=res["status"],
            summary=res.get("summary", {}),
            decisions_written=res.get("decisions_written", 0),
            forecasts_written=res.get("forecasts_written", 0),
        )
    except Exception as exc:
        logger.error("Optimizer error: %s", exc)
        raise HTTPException(status_code=500, detail=f"Optimizer error: {exc}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api_server:app", host="0.0.0.0", port=8000, reload=True)
