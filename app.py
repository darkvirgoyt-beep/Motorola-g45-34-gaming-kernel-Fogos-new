#!/usr/bin/env python3
"""
FogOS Kernel — Build Trigger Dashboard
Developer: Prince · VirgoYT707
Device   : Motorola G45 / G34 (SM6375 — Holi)
"""

import os
import json
import urllib.request
import urllib.error
from flask import Flask, render_template, request, jsonify, Response, stream_with_context

app = Flask(__name__)

GITHUB_REPO   = "darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new"
GITHUB_BRANCH = "sixteen-qpr2"
WORKFLOW_FILE  = "build.yml"


def _gh_token():
    return os.environ.get("FOGOS_GITHUB_TOKEN", "")


def _gh_request(path: str, method: str = "GET", payload: dict | None = None,
                accept: str = "application/vnd.github+json"):
    """Make a GitHub API request. Returns (status_code, parsed_json_or_None)."""
    token = _gh_token()
    url = f"https://api.github.com/{path}"
    headers = {
        "Accept": accept,
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "FogOS-Dashboard/3",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    data = json.dumps(payload).encode() if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return e.code, json.loads(body)
        except Exception:
            return e.code, {"message": body.decode(errors="replace")}
    except Exception as e:
        return 0, {"message": str(e)}


# ─────────────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html",
                           repo=GITHUB_REPO,
                           branch=GITHUB_BRANCH,
                           has_token=bool(_gh_token()))


@app.route("/api/runs")
def api_runs():
    """Return the 10 most recent workflow runs."""
    status, data = _gh_request(
        f"repos/{GITHUB_REPO}/actions/workflows/{WORKFLOW_FILE}/runs?per_page=10"
    )
    if status == 200 and data:
        runs = []
        for r in data.get("workflow_runs", []):
            runs.append({
                "id":          r["id"],
                "name":        r.get("display_title") or r.get("name", ""),
                "status":      r["status"],
                "conclusion":  r.get("conclusion"),
                "created_at":  r["created_at"],
                "updated_at":  r["updated_at"],
                "html_url":    r["html_url"],
                "head_branch": r.get("head_branch", ""),
                "run_number":  r["run_number"],
            })
        return jsonify({"ok": True, "runs": runs})
    return jsonify({"ok": False,
                    "error": data.get("message", "Unknown error") if data else "No response",
                    "status": status})


@app.route("/api/run/<int:run_id>/jobs")
def api_run_jobs(run_id):
    """Return jobs and their steps for a specific run."""
    status, data = _gh_request(
        f"repos/{GITHUB_REPO}/actions/runs/{run_id}/jobs?per_page=10"
    )
    if status == 200 and data:
        jobs = []
        for j in data.get("jobs", []):
            steps = []
            for s in j.get("steps", []):
                steps.append({
                    "name":       s.get("name", ""),
                    "status":     s.get("status", ""),
                    "conclusion": s.get("conclusion"),
                    "number":     s.get("number", 0),
                    "started_at": s.get("started_at"),
                    "completed_at": s.get("completed_at"),
                })
            jobs.append({
                "id":           j["id"],
                "name":         j["name"],
                "status":       j["status"],
                "conclusion":   j.get("conclusion"),
                "started_at":   j.get("started_at"),
                "completed_at": j.get("completed_at"),
                "html_url":     j.get("html_url", ""),
                "steps":        steps,
            })
        return jsonify({"ok": True, "jobs": jobs})
    return jsonify({"ok": False,
                    "error": (data or {}).get("message", f"HTTP {status}"),
                    "status": status})


@app.route("/api/run/<int:run_id>/logs")
def api_run_logs(run_id):
    """
    Stream logs for a run's first job.
    GitHub returns a redirect to a signed zip URL; we follow it and stream the text.
    """
    token = _gh_token()
    if not token:
        return jsonify({"ok": False, "error": "No token"}), 400

    # First get the job ID
    status, data = _gh_request(
        f"repos/{GITHUB_REPO}/actions/runs/{run_id}/jobs?per_page=1"
    )
    if status != 200 or not data or not data.get("jobs"):
        return jsonify({"ok": False, "error": "No jobs found"}), 404

    job_id = data["jobs"][0]["id"]

    # Request logs — GitHub redirects to a signed URL
    log_url = f"https://api.github.com/repos/{GITHUB_REPO}/actions/jobs/{job_id}/logs"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "FogOS-Dashboard/3",
    }
    req = urllib.request.Request(log_url, headers=headers)
    try:
        # urllib follows redirects automatically
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        # Trim to last 200 lines so the UI stays readable
        lines = raw.splitlines()
        trimmed = lines[-200:] if len(lines) > 200 else lines
        return jsonify({"ok": True, "log": "\n".join(trimmed), "total_lines": len(lines)})
    except urllib.error.HTTPError as e:
        if e.code == 410:
            return jsonify({"ok": False, "error": "Logs expired or build not finished yet"}), 410
        return jsonify({"ok": False, "error": f"HTTP {e.code}"}), e.code
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/trigger", methods=["POST"])
def api_trigger():
    """Dispatch the build workflow."""
    token = _gh_token()
    if not token:
        return jsonify({"ok": False,
                        "error": "FOGOS_GITHUB_TOKEN secret is not set. Add it in Replit Secrets."}), 400

    body = request.get_json(force=True, silent=True) or {}
    release    = "true" if body.get("release") else "false"
    prerelease = "true" if body.get("prerelease") else "false"
    version_tag = body.get("version_tag", "")

    payload = {
        "ref": GITHUB_BRANCH,
        "inputs": {
            "release":     release,
            "prerelease":  prerelease,
            "version_tag": version_tag,
        }
    }

    status, data = _gh_request(
        f"repos/{GITHUB_REPO}/actions/workflows/{WORKFLOW_FILE}/dispatches",
        method="POST",
        payload=payload,
    )

    if status == 204:
        return jsonify({"ok": True, "message": "Build triggered! Watch the run appear below."})

    err_msg = (data or {}).get("message", f"HTTP {status}")
    hints = {
        401: "Token is invalid or missing 'repo' scope.",
        403: "Token lacks permission — ensure it has Actions: write + Contents: write.",
        404: "Workflow not found or repo is private and token lacks access.",
        422: f"Branch '{GITHUB_BRANCH}' not found or workflow_dispatch not enabled.",
    }
    hint = hints.get(status, "")
    return jsonify({"ok": False, "error": err_msg, "hint": hint, "status": status}), 400


@app.route("/api/token-status")
def api_token_status():
    token = _gh_token()
    if not token:
        return jsonify({"set": False})
    status, data = _gh_request("user")
    if status == 200 and data:
        return jsonify({"set": True, "user": data.get("login", ""), "valid": True})
    return jsonify({"set": True, "valid": False, "error": (data or {}).get("message", "")})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
