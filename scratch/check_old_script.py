import paramiko

HOST = "192.168.0.24"
USER = "pi"
PASS = "vijwus-moJxix9"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(HOST, username=USER, password=PASS, timeout=10)
        
        # Read the first 25 lines of the old cam_server.py to see how it inits the display
        stdin, stdout, stderr = ssh.exec_command("head -n 25 /home/pi/cam_server.py")
        
        content = stdout.read().decode('utf-8', errors='replace')
        
        with open("scratch/cam_server_head.txt", "w", encoding="utf-8") as f:
            f.write(content)
            
        print("Log saved to scratch/cam_server_head.txt")
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
