using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Meridian.AR.Schema;

namespace Meridian.AR
{
    /// <summary>
    /// Intercepts haptic payload schemas and routes them to the physical wrist_puck via MQTT.
    /// </summary>
    public class HapticBridge : MonoBehaviour
    {
        // Reference to the MQTT Client that handles high-frequency pub/sub
        // public MqttClient mqttClient;

        public void ProcessHapticElement(UIElement hapticElement)
        {
            // Calculate distance from Quest hand position to the spatial target
            // In a real implementation, we query the OVRHand or similar Quest SDK component
            float mockDistanceToTarget = 0.5f; 

            if (hapticElement.type == "Error_Alert")
            {
                TriggerErrorPulse(hapticElement);
                return;
            }

            // Haptic_Beacon logic
            // Modulate the haptic intensity based on proximity to the spatial position
            if (mockDistanceToTarget < 1.0f)
            {
                float intensityMultiplier = 1.0f - mockDistanceToTarget; // Closer = stronger
                float modulatedFreq = hapticElement.frequency * intensityMultiplier;
                float modulatedAmp = hapticElement.amplitude * intensityMultiplier;

                DispatchMqttPulse(modulatedFreq, modulatedAmp, hapticElement.pattern);
            }
        }

        private void TriggerErrorPulse(UIElement element)
        {
            Debug.Log("[HapticBridge] ERROR ALERT Triggered! Sending max amplitude pulse to wrist_puck.");
            // Send max amplitude buzz pattern
            DispatchMqttPulse(300.0f, 1.0f, "Solid_Buzz");
        }

        private void DispatchMqttPulse(float freq, float amp, string pattern)
        {
            string payload = $"{{\"freq\":{freq}, \"amp\":{amp}, \"pattern\":\"{pattern}\"}}";
            Debug.Log($"[MQTT] Publish -> Topic: meridian/haptics/wrist_puck/pulse | Payload: {payload}");
            
            // if (mqttClient != null)
            // {
            //     mqttClient.Publish("meridian/haptics/wrist_puck/pulse", payload);
            // }
        }
    }
}
