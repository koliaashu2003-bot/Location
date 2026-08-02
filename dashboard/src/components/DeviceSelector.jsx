// Dropdown to pick which tracked family member to view.
export default function DeviceSelector({ devices, selectedId, onSelect }) {
  if (!devices || devices.length === 0) {
    return (
      <div className="text-sm text-gray-500">No devices tracked yet.</div>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <label htmlFor="device" className="text-sm font-medium text-gray-700">
        Device:
      </label>
      <select
        id="device"
        value={selectedId || ''}
        onChange={(e) => onSelect(e.target.value)}
        className="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
      >
        {devices.map((d) => (
          <option key={d.id} value={d.id}>
            {d.deviceName || d.id}
          </option>
        ))}
      </select>
    </div>
  );
}
