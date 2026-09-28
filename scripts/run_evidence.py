#!/usr/bin/env python3
"""Run the curated evidence commands and keep a screenshot-friendly transcript.

The challenge repository contains both final evidence tools and exploratory
scanners that were superseded during the investigation.  This runner names the
final tools explicitly instead of executing every file in ``scripts/``.

By default it runs the read-only Python evidence tools.  Use ``--with-forge``
to add the useful Foundry inspectors and ``--with-score`` to run the challenge
score checks after the evidence pass.

Every job is written to its own log under ``evidence-runs/`` and is also echoed
to the terminal.  A failed job is recorded and the runner continues, so one
provider limit does not erase the logs produced by the other jobs.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCK_ID = "0x0159fa4cd496a40b6531521bb9138a06"


@dataclass(frozen=True)
class Job:
    name: str
    command: tuple[str, ...]


def python_job(name: str, script: str, *args: str) -> Job:
    return Job(name, (sys.executable, f"scripts/{script}", *args))


PYTHON_JOBS: tuple[Job, ...] = (
    python_job("case01_stacks_schema", "inspect_stacks_api.py"),
    python_job("case01_find_matching_lock", "find_stacks_lock.py", LOCK_ID),
    python_job("case02_scheduled_auctions", "list_dutchx_auctions.py"),
    python_job("case06_cashcat_mint", "inspect_cashcat_launch.py"),
    python_job("case06_cashcat_approvals", "inspect_cashcat_approvals.py"),
    python_job("case08_first_move_both_chains", "inspect_first_move_op.py", "--chain", "all"),
)


def forge_job(name: str, path: str) -> Job:
    return Job(name, ("forge", "test", "--match-path", path, "-vv"))


# These tests are the inspectors and simulations that produced evidence used
# in the final reasoning.  The exploratory or provider-stress tests are not in
# this default list; they can still be run manually when investigating RPCs.
FORGE_JOBS: tuple[Job, ...] = (
    forge_job("case02_auction_state", "challenges/02-falling-dutchman/AuctionInspector.t.sol"),
    forge_job("case02_external_knc_price", "challenges/02-falling-dutchman/ExternalPriceInspector.t.sol"),
    forge_job("case03_liquity_state", "challenges/03-too-big-to-fail/LiquityInspector.t.sol"),
    forge_job("case06_l2_cashcat", "challenges/06-cold-start/L2Inspector.t.sol"),
    forge_job("case06_retryable_envelope", "challenges/06-cold-start/InboxEnvelopeInspector.t.sol"),
    forge_job("case06_uniswap_pool", "challenges/06-cold-start/UniswapInspector.t.sol"),
    forge_job("case06_swap_simulation", "challenges/06-cold-start/SwapSimulation.t.sol"),
    forge_job("case07_firepit_state", "challenges/07-firepit/FirepitInspector.t.sol"),
    forge_job("case07_fee_basket", "challenges/07-firepit/FeeBasketInspector.t.sol"),
    forge_job("case07_liquid_route_graph", "challenges/07-firepit/LiquidRouteState.t.sol"),
    forge_job("case07_direct_exit_quotes", "challenges/07-firepit/CoreLiquidationQuotes.t.sol"),
)


SCORE_JOBS: tuple[Job, ...] = tuple(
    Job(f"score_case_{case:02d}", (sys.executable, "alpha.py", "check", f"{case:02d}"))
    for case in range(1, 9)
)


def timestamped_output_dir(explicit: str | None) -> Path:
    if explicit:
        output = Path(explicit).expanduser()
        if not output.is_absolute():
            output = ROOT / output
    else:
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        output = ROOT / "evidence-runs" / stamp

    # Do not overwrite a previous screenshot run.
    candidate = output
    suffix = 2
    while candidate.exists():
        candidate = output.with_name(f"{output.name}-{suffix}")
        suffix += 1
    candidate.mkdir(parents=True, exist_ok=False)
    return candidate


def run_job(job: Job, log_path: Path, number: int, total: int) -> int:
    rendered = shlex.join(job.command)
    banner = f"\n{'=' * 78}\n[{number}/{total}] {job.name}\n$ {rendered}\n{'=' * 78}"
    print(banner, flush=True)

    with log_path.open("w", encoding="utf-8") as log:
        log.write(banner + "\n")
        try:
            process = subprocess.Popen(
                job.command,
                cwd=ROOT,
                env=os.environ.copy(),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except OSError as error:
            message = f"Could not start job: {error}"
            print(message, flush=True)
            log.write(message + "\n")
            return 127

        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="", flush=True)
            log.write(line)
        return process.wait()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--with-forge",
        action="store_true",
        help="also run the curated Foundry inspectors and simulations",
    )
    parser.add_argument(
        "--with-score",
        action="store_true",
        help="also run alpha.py check 01 through 08",
    )
    parser.add_argument(
        "--output-dir",
        help="directory for logs (default: evidence-runs/<timestamp>)",
    )
    args = parser.parse_args()

    jobs: list[Job] = list(PYTHON_JOBS)
    if args.with_forge:
        jobs.extend(FORGE_JOBS)
    if args.with_score:
        jobs.extend(SCORE_JOBS)

    output_dir = timestamped_output_dir(args.output_dir)
    summary: list[tuple[str, int]] = []

    print(f"Evidence logs will be saved under: {output_dir}")
    print("Only curated final-evidence commands are included by default.")
    print("The X Layer pool-range scanners are intentionally excluded because they were superseded.")

    for index, job in enumerate(jobs, start=1):
        log_path = output_dir / f"{index:02d}-{job.name}.log"
        return_code = run_job(job, log_path, index, len(jobs))
        summary.append((job.name, return_code))
        status = "PASS" if return_code == 0 else f"FAIL ({return_code})"
        print(f"\n[{status}] {job.name}  log: {log_path}\n", flush=True)

    summary_path = output_dir / "SUMMARY.txt"
    with summary_path.open("w", encoding="utf-8") as summary_file:
        summary_file.write(f"Evidence run: {dt.datetime.now().isoformat(timespec='seconds')}\n")
        summary_file.write(f"Jobs: {len(summary)}\n\n")
        for name, return_code in summary:
            status = "PASS" if return_code == 0 else f"FAIL ({return_code})"
            summary_file.write(f"{status:>10}  {name}\n")

    failures = sum(return_code != 0 for _, return_code in summary)
    print(f"{'=' * 78}")
    print(f"Completed {len(summary)} jobs: {len(summary) - failures} passed, {failures} failed.")
    print(f"Summary: {summary_path}")
    print(f"Logs:    {output_dir}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
