using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Meridian.AR.Schema;
using System.Net.Sockets;
using System.Text;
using System.Net;

namespace Meridian.AR
{
    /// <summary>
    /// Intercepts haptic payload schemas and routes them to the physical wrist_puck via UDP.
    /// UDP is much faster and more direct than MQTT for local network haptics!
    /// </summary>
    public class HapticBridge : MonoBehaviour
    {
        [Header("Wrist Puck Connection")]
        [Tooltip("The IP Address of the ESP32 Wrist Puck")]
        public string puckIpAddress = "192.168.1.100";
        public int puckUdpPort = 9000;

        private UdpClient udpClient;

        void Start()
        {
            udpClient = new UdpClient();
            Debug.Log($"[HapticBridge] UDP Client initialized. Targeting {puckIpAddress}:{puckUdpPort}");
        }

        public void ProcessHapticElement(UIElement hapticElement)
        {
            float mockDistanceToTarget = 0.5f; 

            if (hapticElement.type == "Error_Alert")
            {
                TriggerErrorPulse(hapticElement);
                return;
            }

            if (mockDistanceToTarget < 1.0f)
            {
                float intensityMultiplier = 1.0f - mockDistanceToTarget; // Closer = stronger
                int amplitude = Mathf.Clamp(Mathf.RoundToInt(hapticElement.amplitude * intensityMultiplier * 127), 0, 127);
                
                DispatchRtpMotif(amplitude);
            }
        }

        private void TriggerErrorPulse(UIElement element)
        {
            Debug.Log("[HapticBridge] ERROR ALERT Triggered! Sending strong click effect to wrist_puck.");
            // Effect 1 = Strong Click, 47 = Buzz
            DispatchEffectMotif(47, 500); 
        }

        private void DispatchEffectMotif(int effectId, int durationMs)
        {
            // Matches the parsing logic in wrist_puck_haptic_node.ino
            string payload = $"{{\"id\":\"alert\", \"repeat\":1, \"steps\":[{{\"ch\":\"lra\", \"type\":\"effect\", \"effect\":{effectId}, \"dur_ms\":{durationMs}}}]}}";
            SendUdpPacket(payload);
        }

        private void DispatchRtpMotif(int amplitude)
        {
            // Real-Time Playback (RTP) mode for continuous buzzing based on distance
            string payload = $"{{\"id\":\"rtp\", \"repeat\":1, \"steps\":[{{\"ch\":\"lra\", \"type\":\"rtp\", \"amplitude\":{amplitude}}}]}}";
            SendUdpPacket(payload);
        }

        private void SendUdpPacket(string jsonPayload)
        {
            if (udpClient == null) return;

            try
            {
                byte[] data = Encoding.UTF8.GetBytes(jsonPayload);
                udpClient.SendAsync(data, data.Length, puckIpAddress, puckUdpPort);
                Debug.Log($"[HapticBridge UDP] Sent: {jsonPayload}");
            }
            catch (System.Exception e)
            {
                Debug.LogError($"[HapticBridge UDP] Failed to send: {e.Message}");
            }
        }

        void OnDestroy()
        {
            if (udpClient != null)
            {
                udpClient.Close();
            }
        }
    }
}
