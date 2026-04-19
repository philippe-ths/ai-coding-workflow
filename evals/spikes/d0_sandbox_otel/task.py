"""
Inspect task for D0 sandbox OTEL spike (#111).

Question: do OTEL resource attributes set via OTEL_RESOURCE_ATTRIBUTES inside
an Inspect Docker sandbox reach the host collector?

The solver copies emit.py into the sandbox, launches python3 with
OTEL_RESOURCE_ATTRIBUTES set in the exec env, and records the result.
A separate assert_tags.py polls Loki to confirm the attributes arrived.
"""
import uuid
from pathlib import Path

from inspect_ai import Task, task
from inspect_ai.dataset import Sample
from inspect_ai.solver import Generate, Solver, TaskState, solver
from inspect_ai.util import sandbox

SPIKE_DIR = Path(__file__).parent


@solver
def sandbox_otel_ping() -> Solver:
    async def solve(state: TaskState, generate: Generate) -> TaskState:
        run_id = state.metadata["spike_run_id"]
        endpoint = "http://host.docker.internal:4318"

        emit_src = (SPIKE_DIR / "emit.py").read_text()
        await sandbox().write_file("/tmp/emit.py", emit_src)

        result = await sandbox().exec(
            ["python3", "/tmp/emit.py"],
            env={
                "OTEL_RESOURCE_ATTRIBUTES": (
                    f"spike_run_id={run_id},service.name=d0-sandbox-spike"
                ),
                "OTEL_EXPORTER_OTLP_ENDPOINT": endpoint,
            },
        )
        state.metadata["exit_code"] = result.returncode
        state.metadata["stdout"] = result.stdout
        state.metadata["stderr"] = result.stderr
        state.output.completion = (
            f"rc={result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
        return state

    return solve


@task
def d0_sandbox_otel() -> Task:
    run_id = f"sbx-{uuid.uuid4()}"
    (SPIKE_DIR / "run_id.txt").write_text(run_id)
    return Task(
        dataset=[Sample(input="emit one log", metadata={"spike_run_id": run_id})],
        solver=sandbox_otel_ping(),
        sandbox=("docker", str(SPIKE_DIR / "compose.yaml")),
    )
