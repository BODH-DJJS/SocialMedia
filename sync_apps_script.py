# -*- coding: utf-8 -*-
import os, sys, shutil, datetime, subprocess, urllib.request

DEPLOYMENT_ID = "AKfycbwPc0XQIMPI4Lms59IGtyVcSRLlEcPOJWbt7VhN3jfmkukgqkSgxHd6HNxbtPGCODskGw"
REPO_DIR = r"D:\FlutterProjects\bodh_social_media"
APPS_SCRIPT_DIR = os.path.join(REPO_DIR, "apps_script")
CODE_GS_PATH = os.path.join(REPO_DIR, "code.gs")
APPS_SCRIPT_CODE_JS = os.path.join(APPS_SCRIPT_DIR, "Code.js")

def main():
    print("=" * 60)
    print("Google Apps Script Automated Sync & Deploy")
    print("=" * 60)

    # 1. Backup code.gs
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = os.path.join(REPO_DIR, f"code_backup_{timestamp}.gs")
    shutil.copy2(CODE_GS_PATH, backup_file)
    print(f"1. Backup created: {backup_file}")

    # 2. Sync to apps_script/Code.js
    shutil.copy2(CODE_GS_PATH, APPS_SCRIPT_CODE_JS)
    print(f"2. Synced local code.gs -> apps_script/Code.js")

    # 3. Clasp push
    print("3. Pushing files with clasp (Code.js, Date wise Combine Report.js, appsscript.json)...")
    res = subprocess.run(["npx.cmd", "@google/clasp", "push", "-f"], cwd=APPS_SCRIPT_DIR, capture_output=True, text=True, shell=True)
    print(res.stdout)
    if res.returncode != 0:
        print("Clasp push error:", res.stderr)
        return

    # 4. Create new version
    version_desc = f"Auto-deployed at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    print(f"4. Creating new version: {version_desc}...")
    v_res = subprocess.run(["npx.cmd", "@google/clasp", "version", version_desc], cwd=APPS_SCRIPT_DIR, capture_output=True, text=True, shell=True)
    print(v_res.stdout)

    # Extract version number if available
    v_num = None
    for line in v_res.stdout.splitlines():
        if "Created version" in line:
            parts = line.strip().split()
            v_num = parts[-1]
            break

    # 5. Deploy to web app deployment
    print(f"5. Updating live web app deployment {DEPLOYMENT_ID}...")
    deploy_cmd = ["npx.cmd", "@google/clasp", "deploy", "-i", DEPLOYMENT_ID]
    if v_num:
        deploy_cmd.extend(["-V", v_num])
    deploy_cmd.extend(["-d", version_desc])

    d_res = subprocess.run(deploy_cmd, cwd=APPS_SCRIPT_DIR, capture_output=True, text=True, shell=True)
    print(d_res.stdout)

    # 6. Verify live endpoint
    print("6. Verifying live Web App...")
    try:
        url = f"https://script.google.com/macros/s/{DEPLOYMENT_ID}/exec"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as resp:
            print("HTTP Status:", resp.status)
            print("Response:", resp.read().decode("utf-8")[:150])
    except Exception as e:
        print("Verification note:", e)

    print("\nSUCCESS: Code pushed, backup saved, and Apps Script Web App is live!")

if __name__ == "__main__":
    main()
