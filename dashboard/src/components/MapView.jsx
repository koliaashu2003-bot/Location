import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import { useEffect, useMemo } from 'react';
import { useMap } from 'react-leaflet';

// Fix default marker icons not loading under Vite bundling by pointing Leaflet
// at CDN-free inline data or the packaged PNGs.
import markerIcon2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerIcon from 'leaflet/dist/images/marker-icon.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: markerIcon2x,
  iconUrl: markerIcon,
  shadowUrl: markerShadow,
});

// Recenters the map whenever the selected device's latest position changes.
function Recenter({ position }) {
  const map = useMap();
  useEffect(() => {
    if (position) {
      map.setView(position, map.getZoom(), { animate: true });
    }
  }, [position, map]);
  return null;
}

export default function MapView({ current, history }) {
  // Build the ordered trail (oldest → newest) for the last 24 hours.
  const trail = useMemo(
    () =>
      (history || [])
        .filter((h) => h.latitude != null && h.longitude != null)
        .map((h) => [h.latitude, h.longitude]),
    [history]
  );

  const center = current
    ? [current.latitude, current.longitude]
    : trail.length > 0
    ? trail[trail.length - 1]
    : [20.5937, 78.9629]; // Default: India centroid.

  return (
    <div className="h-[420px] w-full overflow-hidden rounded-xl shadow">
      <MapContainer center={center} zoom={13} scrollWheelZoom={true}>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {trail.length > 1 && (
          <Polyline positions={trail} color="#6366f1" weight={4} opacity={0.7} />
        )}

        {current && (
          <Marker position={[current.latitude, current.longitude]}>
            <Popup>
              <div className="text-sm">
                <strong>{current.deviceName || 'Device'}</strong>
                <br />
                Battery: {current.battery ?? '—'}%
                <br />
                {current.timestamp
                  ? new Date(current.timestamp).toLocaleString()
                  : ''}
              </div>
            </Popup>
          </Marker>
        )}

        <Recenter position={current ? [current.latitude, current.longitude] : null} />
      </MapContainer>
    </div>
  );
}
