from fastapi import APIRouter, Depends, HTTPException

from app.agent.planner import AgentPlanner
from app.deps import get_planner, require_device
from app.schemas.agent import CommandIn, ResultIn, StepOut

router = APIRouter(prefix="/v1/agent", tags=["agent"])


@router.post("/command", response_model=StepOut)
async def command(body: CommandIn, device: str = Depends(require_device), planner: AgentPlanner = Depends(get_planner)) -> StepOut:
    return await planner.start(device, body.transcript, body.locale, body.device_caps)


@router.post("/{session_id}/result", response_model=StepOut)
async def result(session_id: str, body: ResultIn, device: str = Depends(require_device), planner: AgentPlanner = Depends(get_planner)) -> StepOut:
    out = await planner.submit(device, session_id, body.results)
    if out is None:
        raise HTTPException(404, "unknown or expired session")
    return out


@router.post("/{session_id}/cancel")
def cancel(session_id: str, device: str = Depends(require_device), planner: AgentPlanner = Depends(get_planner)) -> dict:
    return {"cancelled": planner.cancel(device, session_id)}
