import paramiko

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        
        commands = [
            "echo 'vijwus-moJxix9' | sudo -S pkill -f cam_server.py",
            "echo 'vijwus-moJxix9' | sudo -S systemctl restart skycam.service"
        ]
        
        for cmd in commands:
            print(f"\n--- {cmd} ---")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            print(stdout.read().decode('utf-8', errors='ignore'))
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
