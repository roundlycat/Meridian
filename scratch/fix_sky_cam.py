import paramiko
import sys

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

def run_sudo_command(ssh, cmd):
    print(f"--- Running: {cmd} ---")
    full_cmd = f"echo '{PASS}' | sudo -S {cmd}"
    stdin, stdout, stderr = ssh.exec_command(full_cmd)
    
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    
    try:
        print(out)
        if err and "[sudo] password" not in err:
            print(f"ERR: {err}")
    except:
        pass
        
    exit_status = stdout.channel.recv_exit_status()
    print(f"--- Exit code: {exit_status} ---")

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        
        run_sudo_command(ssh, "systemctl enable skycam.service")
        run_sudo_command(ssh, "systemctl restart skycam.service")
        run_sudo_command(ssh, "systemctl status skycam.service --no-pager")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
