import { useState, useEffect } from 'preact/hooks';

interface SensorData {
  time: string;
  img: string | null;
  temp: number | null;
  hum: number | null;
}

const STORAGE_BASE = 'https://storage.zhivaya.dev';
const POLL_INTERVAL = 5 * 60 * 1000; // 5 minutes

export default function SensorViewer() {
  const [allData, setAllData] = useState<SensorData[]>([]);
  const [sensorData, setSensorData] = useState<SensorData[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [imageError, setImageError] = useState(false);

  const fetchData = async () => {
    try {
      const response = await fetch(`${STORAGE_BASE}/sensor_data.json`);
      if (!response.ok) {
        throw new Error(`Failed to fetch: ${response.status}`);
      }
      const data: SensorData[] = await response.json();
      setAllData(data);
      // Filter only data with images for slider
      const dataWithImages = data.filter(item => item.img !== null);
      setSensorData(dataWithImages);
      // Set to latest data (last index)
      setCurrentIndex(dataWithImages.length - 1);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch data');
    } finally {
      setLoading(false);
    }
  };

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, []);

  // Auto-polling every 5 minutes
  useEffect(() => {
    const interval = setInterval(() => {
      fetchData();
    }, POLL_INTERVAL);

    return () => clearInterval(interval);
  }, []);

  // Reset image error when index changes
  useEffect(() => {
    setImageError(false);
  }, [currentIndex]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--gray)' }}>
        <p>Loading...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div
        style={{
          textAlign: 'center',
          padding: '2rem',
          backgroundColor: 'var(--black)',
          borderRadius: '4px',
          border: '1px solid var(--pink)',
        }}
      >
        <p style={{ color: 'var(--pink)' }}>Error: {error}</p>
      </div>
    );
  }

  if (sensorData.length === 0) {
    return (
      <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--gray)' }}>
        <p>No data available</p>
      </div>
    );
  }

  const currentData = sensorData[currentIndex];
  const latestData = allData.length > 0 ? allData[allData.length - 1] : null;
  const hasImage = currentData.img !== null;
  const imageUrl = hasImage ? `${STORAGE_BASE}/${currentData.img}` : null;
  const showPlaceholder = !hasImage || imageError;

  // Format time for display
  const formatTime = (timeStr: string) => {
    // Format: YYYYMMDD_HHMMSS -> YYYY/MM/DD HH:MM:SS
    const year = timeStr.slice(0, 4);
    const month = timeStr.slice(4, 6);
    const day = timeStr.slice(6, 8);
    const hour = timeStr.slice(9, 11);
    const minute = timeStr.slice(11, 13);
    const second = timeStr.slice(13, 15);
    return `${year}/${month}/${day} ${hour}:${minute}:${second}`;
  };

  return (
    <div>
      {/* Latest Sensor Data Display */}
      {latestData && (
        <div
          style={{
            marginBottom: '1.5rem',
            padding: '1rem',
            border: '1px solid var(--gray)',
          }}
        >
          <div style={{ fontSize: '0.875rem', color: 'var(--gray)', marginBottom: '0.75rem' }}>
            Latest Sensor Data
          </div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr 1fr',
              gap: '1rem',
            }}
          >
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--gray)', marginBottom: '0.25rem' }}>
                Time
              </div>
              <div style={{ fontSize: '0.875rem', color: 'var(--white)', fontWeight: 'bold' }}>
                {formatTime(latestData.time)}
              </div>
            </div>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--gray)', marginBottom: '0.25rem' }}>
                Temperature
              </div>
              <div style={{ fontSize: '1.25rem', color: 'var(--white)', fontWeight: 'bold' }}>
                {latestData.temp !== null ? `${latestData.temp.toFixed(2)}°C` : 'N/A'}
              </div>
            </div>
            <div>
              <div style={{ fontSize: '0.75rem', color: 'var(--gray)', marginBottom: '0.25rem' }}>
                Humidity
              </div>
              <div style={{ fontSize: '1.25rem', color: 'var(--white)', fontWeight: 'bold' }}>
                {latestData.hum !== null ? `${latestData.hum.toFixed(2)}%` : 'N/A'}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Image Display with Overlay Data */}
      <div
        style={{
          marginBottom: '1.5rem',
          backgroundColor: 'var(--black)',
          overflow: 'hidden',
          border: '1px solid var(--gray)',
          aspectRatio: '4/3',
          position: 'relative',
        }}
      >
        {showPlaceholder ? (
          <div
            style={{
              width: '100%',
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'var(--gray)',
              fontSize: '1.25rem',
              gap: '0.5rem',
            }}
          >
            <div style={{ fontSize: '1.5rem' }}>🌙</div>
            <div>Night Mode - Camera Off</div>
          </div>
        ) : (
          <img
            src={imageUrl!}
            alt={`Sensor image at ${currentData.time}`}
            onError={() => setImageError(true)}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
              display: 'block',
            }}
          />
        )}

        {/* Sensor Data Overlay */}
        <div
          class="sensor-data-grid"
          style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            right: 0,
            display: 'grid',
            gridTemplateColumns: '1fr 1fr 1fr',
            gap: '1rem',
            padding: '1rem',
          }}
        >
          <div>
            <div style={{
              fontSize: '0.75rem',
              color: 'rgba(255, 255, 255, 0.7)',
              marginBottom: '0.25rem',
              textShadow: '0 1px 3px rgba(0, 0, 0, 0.8)',
            }}>
              Time
            </div>
            <div style={{
              fontSize: '0.875rem',
              color: 'rgba(255, 255, 255, 0.9)',
              fontWeight: 'bold',
              textShadow: '0 1px 4px rgba(0, 0, 0, 0.9)',
            }}>
              {formatTime(currentData.time)}
            </div>
          </div>
          <div>
            <div style={{
              fontSize: '0.75rem',
              color: 'rgba(255, 255, 255, 0.7)',
              marginBottom: '0.25rem',
              textShadow: '0 1px 3px rgba(0, 0, 0, 0.8)',
            }}>
              Temperature
            </div>
            <div style={{
              fontSize: '1.5rem',
              color: 'rgba(255, 255, 255, 0.95)',
              fontWeight: 'bold',
              textShadow: '0 1px 4px rgba(0, 0, 0, 0.9)',
            }}>
              {currentData.temp !== null ? `${currentData.temp.toFixed(2)}°C` : 'N/A'}
            </div>
          </div>
          <div>
            <div style={{
              fontSize: '0.75rem',
              color: 'rgba(255, 255, 255, 0.7)',
              marginBottom: '0.25rem',
              textShadow: '0 1px 3px rgba(0, 0, 0, 0.8)',
            }}>
              Humidity
            </div>
            <div style={{
              fontSize: '1.5rem',
              color: 'rgba(255, 255, 255, 0.95)',
              fontWeight: 'bold',
              textShadow: '0 1px 4px rgba(0, 0, 0, 0.9)',
            }}>
              {currentData.hum !== null ? `${currentData.hum.toFixed(2)}%` : 'N/A'}
            </div>
          </div>
        </div>
      </div>

      {/* Slider Control */}
      <div>
        <div style={{ fontSize: '0.875rem', color: 'var(--gray)', marginBottom: '0.5rem' }}>
          Image History (Daytime Only)
        </div>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            marginBottom: '0.5rem',
            fontSize: '0.875rem',
            color: 'var(--gray)',
          }}
        >
          <span>Oldest</span>
          <span style={{ color: 'var(--white)' }}>
            {currentIndex + 1} / {sensorData.length}
          </span>
          <span>Latest</span>
        </div>
        <input
          type="range"
          min="0"
          max={sensorData.length - 1}
          value={currentIndex}
          onInput={(e) => setCurrentIndex(parseInt((e.target as HTMLInputElement).value))}
          style={{
            width: '100%',
            accentColor: 'var(--pink)',
          }}
        />
      </div>
    </div>
  );
}
