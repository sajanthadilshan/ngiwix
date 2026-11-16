import subprocess
import json
from pathlib import Path
import re

SCRIPT_DIR = Path("/scripts")

#wireguard

def addWgTunnel(tunnelId):
    try:
        result = subprocess.run(
            ["bash", SCRIPT_DIR / "wireguard" / "addTunnel.sh", tunnelId],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(result.stdout)

        if isinstance(data, dict) and "success" in data:
            if data["success"] == "ok":
                config_path = data["data"]["config_path"]
                try:
                    file = Path(config_path).read_text(encoding="utf-8")
                    return file
                except OSError as e:
                    print(f"error reading config: {e}")
                    return False
            else:
                return False
        else:
            return False

    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Could not read file: {e}")
        return False


def rmWgTunnel(tunnelId):
    try:
        result = subprocess.run(
            ["bash", SCRIPT_DIR / "wireguard" / "removeTunnel.sh", tunnelId],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(result.stdout)

        if isinstance(data, dict) and "success" in data:
            if data["success"] == "ok":
                return "ok"
            else:
                return False
        else:
            return False

    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Could not read file: {e}")
        return False


def listwgTunnels():
    params = Path("/etc/wireguard") / "params"
    if not params.is_file():
        return json.dumps({"success": "error", "data": {}})

    # params is KEY=value lines; only SERVER_WG_NIC is needed
    m = re.search(r"^SERVER_WG_NIC=(\S+)", params.read_text(), re.M)
    conf = Path("/etc/wireguard") / f"{m.group(1)}.conf" if m else None
    if not conf or not conf.is_file():
        return json.dumps({"success": "error", "data": {}})

    # ### Client <name> ... AllowedIPs = <ipv4>/32,<ipv6>/128
    pattern = re.compile(
        r"^### Client\s+(\S+)\s*\n"
        r"(?:(?!###).*\n)*?" #skip PublicKey,PresharedKey lines
        r"^AllowedIPs\s*=\s*([^/\s,]+)/32\s*,\s*([^/\s,]+)/128",
        re.M,
    )
    tunnels = [
        {"name": name, "ipv4": ipv4, "ipv6": ipv6}
        for name, ipv4, ipv6 in pattern.findall(conf.read_text())
    ]
    return tunnels or False



#nginix

def addNewConfig(domain, clientIp, clientPort, SSL = 'no'):
    try:
        result = subprocess.run(
            ["bash", SCRIPT_DIR / "nginx" / "addConfig.sh", domain, clientIp, clientPort, SSL],
            capture_output=True,
            text=True,
            check=True
        )
        # print(result.stdout)
        data = json.loads(result.stdout)

        if isinstance(data, dict) and "success" in data:
            if data["success"] == "ok":
                return "ok"
            else:
                return False
        else:
            return False

    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Could not read file: {e}")
        return False


def removeConfig(domain):
    try:
        result = subprocess.run(
            ["bash", SCRIPT_DIR / "nginx" / "removeConfig.sh", domain],
            capture_output=True,
            text=True,
            check=True
        )
        # print(result.stdout)
        data = json.loads(result.stdout)

        if isinstance(data, dict) and "success" in data:
            if data["success"] == "ok":
                return "ok"
            else:
                return False
        else:
            return False

    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Could not read file: {e}")
        return False



def getAllConfig() -> str:
    result = []
    for p in sorted(Path("/nginx/conf.d").glob("*.conf")):
        m = re.search(r"^\s*proxy_pass\s+https?://([^:/;\s]+):?(\d+)?", p.read_text(), re.M)
        result.append({
            "domain_name": p.stem,
            "host_ip": m.group(1) if m else None,
            "host_port": m.group(2) if m else None,
        })
    return result




# print(addNewConfig("my.com", "145.24.23.12", "8080"))
# print(removeConfig("my.com"))
print(listwgTunnels())
#print(getAllConfig())




