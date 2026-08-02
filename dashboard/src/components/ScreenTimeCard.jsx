// Shows today's top apps with duration bars and a total for one device.

function formatDuration(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

export default function ScreenTimeCard({ deviceName, apps, totalMinutes }) {
  const hasData = apps && apps.length > 0;
  const maxMinutes = hasData
    ? Math.max(...apps.map((a) => a.durationMinutes || 0), 1)
    : 1;

  return (
    <div className="rounded-xl bg-white p-5 shadow">
      <div className="mb-4 flex items-baseline justify-between">
        <h3 className="text-lg font-semibold text-gray-800">
          📱 Screen Time
        </h3>
        <span className="text-sm text-gray-500">
          Total: {formatDuration(totalMinutes || 0)}
        </span>
      </div>

      {deviceName && (
        <p className="mb-3 text-sm text-gray-600">{deviceName}</p>
      )}

      {!hasData ? (
        <p className="text-sm text-gray-400">
          No screen time recorded today yet.
        </p>
      ) : (
        <ul className="space-y-3">
          {apps.map((app, i) => {
            const pct = Math.round(
              ((app.durationMinutes || 0) / maxMinutes) * 100
            );
            return (
              <li key={`${app.appName}-${i}`}>
                <div className="mb-1 flex justify-between text-sm">
                  <span className="font-medium text-gray-700">
                    {i + 1}. {app.appName}
                  </span>
                  <span className="text-gray-500">
                    {formatDuration(app.durationMinutes || 0)}
                  </span>
                </div>
                <div className="h-2 w-full overflow-hidden rounded-full bg-gray-100">
                  <div
                    className="h-full rounded-full bg-indigo-500"
                    style={{ width: `${pct}%` }}
                  />
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
