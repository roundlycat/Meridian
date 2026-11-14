using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;
using Meridian.AR.Schema;

namespace Meridian.AR
{
    /// <summary>
    /// Core Interpreter Engine for the Living Generative UI.
    /// Listens for JSON schema payloads and dynamically manages the UI components.
    /// </summary>
    public class DynamicUIManager : MonoBehaviour
    {
        // Reference to the Haptic Orchestrator to forward haptic specific schemas
        public HapticBridge hapticBridge;

        [Header("UI Toolkit References")]
        public UIDocument rootDocument;
        public VisualTreeAsset telemetryCardTemplate;

        // Tracks active instanced UI elements by targetObjectID or type to update them rather than recreate
        private Dictionary<string, VisualElement> activeUIElements = new Dictionary<string, VisualElement>();
        private VisualElement rootContainer;

        private void OnEnable()
        {
            if (rootDocument != null)
            {
                rootContainer = rootDocument.rootVisualElement;
            }
        }

        public void OnSchemaReceived(string jsonPayload)
        {
            try
            {
                // Parse the Gemini generated JSON schema
                InterfaceSchema schema = JsonUtility.FromJson<InterfaceSchema>(jsonPayload);
                ProcessSchema(schema);
            }
            catch (System.Exception e)
            {
                Debug.LogError($"[DynamicUIManager] Failed to parse schema: {e.Message}");
            }
        }

        public void OnPerceptualEventReceived(PerceptualEvent perceptualEvent)
        {
            if (perceptualEvent == null)
            {
                Debug.LogWarning("[DynamicUIManager] Received an empty perceptual event.");
                return;
            }

            string nodeId = string.IsNullOrEmpty(perceptualEvent.node_id) ? "Unknown node" : perceptualEvent.node_id;
            string domain = string.IsNullOrEmpty(perceptualEvent.domain) ? "unknown domain" : perceptualEvent.domain;
            string value = perceptualEvent.feature_snapshot != null && !string.IsNullOrEmpty(perceptualEvent.feature_snapshot.render)
                ? perceptualEvent.feature_snapshot.render
                : "No factual reading available.";

            ProcessSchema(new InterfaceSchema
            {
                elements = new List<UIElement>
                {
                    new UIElement
                    {
                        type = "Telemetry_Card",
                        targetObjectID = $"{nodeId}:{domain}",
                        title = $"{nodeId} — {domain}",
                        value = value,
                        color = "#00FFCC"
                    }
                }
            });
        }

        private void ProcessSchema(InterfaceSchema schema)
        {
            if (rootContainer == null)
            {
                Debug.LogWarning("[DynamicUIManager] Root container is null. Please assign a UIDocument.");
                return;
            }

            if (schema == null || schema.elements == null)
            {
                Debug.LogWarning("[DynamicUIManager] Received a schema without elements.");
                return;
            }

            foreach (var element in schema.elements)
            {
                switch (element.type)
                {
                    case "Telemetry_Card":
                        UpdateTelemetryCard(element);
                        break;
                    
                    case "Wireframe_Highlight":
                        UpdateWireframeHighlight(element);
                        break;

                    case "Haptic_Beacon":
                    case "Error_Alert":
                        if (hapticBridge != null)
                        {
                            hapticBridge.ProcessHapticElement(element);
                        }
                        break;
                        
                    default:
                        Debug.LogWarning($"[DynamicUIManager] Unknown element type: {element.type}");
                        break;
                }
            }
        }

        private void UpdateTelemetryCard(UIElement element)
        {
            // Use targetObjectID as a unique key; fallback to type if missing
            string key = string.IsNullOrEmpty(element.targetObjectID) ? element.type : element.targetObjectID;
            
            // If the UI element doesn't exist yet, instantiate it from the UXML template
            if (!activeUIElements.TryGetValue(key, out VisualElement cardInstance))
            {
                if (telemetryCardTemplate == null) 
                {
                    Debug.LogWarning("[DynamicUIManager] No TelemetryCardTemplate assigned.");
                    return;
                }

                cardInstance = telemetryCardTemplate.Instantiate();
                rootContainer.Add(cardInstance);
                activeUIElements[key] = cardInstance;
            }

            // Map the parsed JSON properties directly into the visual labels
            Label titleLabel = cardInstance.Q<Label>("card-title");
            Label valueLabel = cardInstance.Q<Label>("card-value");

            if (titleLabel != null) titleLabel.text = element.title;
            if (valueLabel != null) valueLabel.text = element.value;

            // Map color if Gemini provided one
            if (!string.IsNullOrEmpty(element.color) && ColorUtility.TryParseHtmlString(element.color, out Color parsedColor))
            {
                if (valueLabel != null) valueLabel.style.color = parsedColor;
                // Update the border color dynamically as well
                VisualElement card = cardInstance.Q<VisualElement>(className: "telemetry-card");
                if (card != null)
                {
                    card.style.borderTopColor = parsedColor;
                    card.style.borderBottomColor = parsedColor;
                    card.style.borderLeftColor = parsedColor;
                    card.style.borderRightColor = parsedColor;
                }
            }
            
            Debug.Log($"[UI] Mapped Telemetry Card -> Title: {element.title}, Value: {element.value}");
        }

        private void UpdateWireframeHighlight(UIElement element)
        {
            Debug.Log($"[UI] Wireframe Highlight -> Target: {element.targetObjectID}, Color: {element.color}");
        }
    }
}
