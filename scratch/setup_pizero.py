import paramiko

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

def run_sudo_command(ssh, cmd):
    print(f"\n--- Running: {cmd} ---")
    stdin, stdout, stderr = ssh.exec_command(f"sudo -S {cmd}")
    stdin.write(PASS + "\n")
    stdin.flush()
    
    # Print output as it comes
    for line in iter(stdout.readline, ""):
        print(line, end="")
    for line in iter(stderr.readline, ""):
        # filter out the [sudo] password prompt
        if "[sudo] password" not in line:
            print(f"ERR: {line}", end="")
        
    exit_status = stdout.channel.recv_exit_status()
    print(f"--- Exit code: {exit_status} ---")
    return exit_status

def main():
    print(f"Connecting to {USER}@{HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        print("Connected successfully!")
        
        commands = [
            "apt-get update",
            "raspi-config nonint do_spi 0",
            "apt-get install -y python3-pip python3-pil python3-numpy",
            "pip3 install inky[rpi] paho-mqtt pillow --break-system-packages"
        ]
        
        for cmd in commands:
            run_sudo_command(ssh, cmd)
            
    except Exception as e:
        print(f"Failed to connect or run command: {e}")
    finally:
        ssh.close()
        print("SSH session closed.")

if __name__ == "__main__":
    main()
