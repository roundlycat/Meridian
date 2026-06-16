using System;
using System.Collections.Generic;

namespace Meridian.AR.Schema
{
    [Serializable]
    public class InterfaceSchema
    {
        public string interfaceType;
        public List<UIElement> elements;
    }

    [Serializable]
    public class UIElement
    {
        public string type;             // e.g., "Wireframe_Highlight", "Haptic_Beacon", "Telemetry_Card", "Error_Alert"
        
        // Common visual/UI fields
        public string targetObjectID;
        public string color;
        public float pulseRate;
        public string title;
        public string value;
        
        // Spatial & Haptic fields
        public SpatialPosition spatialPosition;
        public float frequency;
        public float amplitude;
        public string pattern;
    }

    [Serializable]
    public class SpatialPosition
    {
        public float x;
        public float y;
        public float z;
    }
}
