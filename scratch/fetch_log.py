import paramiko

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        
        # Read the last 50 lines of the skycam service log
        stdin, stdout, stderr = ssh.exec_command("journalctl -u skycam.service -n 50 --no-pager")
        
        log_output = stdout.read().decode('utf-8', errors='replace')
        
        with open("scratch/skycam_log.txt", "w", encoding="utf-8") as f:
            f.write(log_output)
            
        print("Log saved to scratch/skycam_log.txt")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
