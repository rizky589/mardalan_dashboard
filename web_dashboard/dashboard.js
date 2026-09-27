// Dashboard JavaScript untuk Tracking Petugas Survey
let map;
let currentLayer;
let heatmapLayer;
let routeLayers = [];
let photoMarkers = [];

// Data cache
let surveysData = [];
let trackingData = [];
let photosData = [];

// Colors untuk setiap petugas
const petugasColors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
    '#F8C471', '#82E0AA', '#F1948A', '#85C1E9', '#D7BDE2'
];

// Initialize map
function initMap() {
    map = L.map('map').setView([2.3274, 99.8492], 12); // Labuhanbatu Utara center
    
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(map);
    
    // Set today's date as default
    const today = new Date().toISOString().split('T')[0];
    document.getElementById('dateFrom').value = today;
    document.getElementById('dateTo').value = today;
    
    // Load initial data
    loadPetugasList();
    loadData();
}

// Load petugas list for dropdown
function loadPetugasList() {
    const select = document.getElementById('petugasSelect');
    
    // Generate 30 petugas (PET001-PET030)
    for (let i = 1; i <= 30; i++) {
        const id = `PET${i.toString().padStart(3, '0')}`;
        const name = `Petugas ${i}`;
        const option = document.createElement('option');
        option.value = id;
        option.textContent = `${id} - ${name}`;
        select.appendChild(option);
    }
}

// Load data from Google Sheets (Real-time mode)
async function loadData() {
    showLoading(true);
    
    try {
        // Try to load real data from Google Sheets first
        const hasRealData = await loadRealData();
        
        if (!hasRealData) {
            // Fallback to demo data if Google Sheets not configured
            await loadDemoData();
        }
        
        const viewMode = document.getElementById('viewMode').value;
        
        // Clear existing layers
        clearLayers();
        
        switch (viewMode) {
            case 'routes':
                showRoutes();
                break;
            case 'heatmap':
                showHeatmap();
                break;
            case 'photos':
                showPhotos();
                break;
        }
        
        updateStats();
        
    } catch (error) {
        console.error('Error loading data:', error);
        alert('Error loading data: ' + error.message);
    } finally {
        showLoading(false);
    }
}

// Load real data from Google Sheets
async function loadRealData() {
    try {
        const spreadsheetId = '1pk0GzWrTnw9SG4OZJx9_TT4BARSMPuQYkZW_a-mvFfc';
        const apiKey = 'YOUR_GOOGLE_SHEETS_API_KEY'; // TODO: Replace with actual API key
        
        // For now, return false to use demo data
        // When Google Sheets API is configured, this will fetch real data
        if (!apiKey || apiKey === 'YOUR_GOOGLE_SHEETS_API_KEY') {
            console.log('Google Sheets API not configured, using demo data');
            return false;
        }
        
        // Fetch surveys data
        const surveysResponse = await fetch(
            `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/surveys!A:K?key=${apiKey}`
        );
        
        // Fetch tracking_logs data  
        const trackingResponse = await fetch(
            `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/tracking_logs!A:G?key=${apiKey}`
        );
        
        // Fetch photo_logs data
        const photosResponse = await fetch(
            `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/photo_logs!A:H?key=${apiKey}`
        );
        
        if (surveysResponse.ok && trackingResponse.ok && photosResponse.ok) {
            const surveysData = await surveysResponse.json();
            const trackingData = await trackingResponse.json();
            const photosData = await photosResponse.json();
            
            // Process real data
            processRealSheetsData(surveysData, trackingData, photosData);
            return true;
        }
        
        return false;
    } catch (error) {
        console.error('Error loading real data:', error);
        return false;
    }
}

// Process real Google Sheets data
function processRealSheetsData(surveysData, trackingData, photosData) {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    const dateFrom = document.getElementById('dateFrom').value;
    const dateTo = document.getElementById('dateTo').value;
    
    // Process surveys (skip header row)
    if (surveysData.values && surveysData.values.length > 1) {
        surveysData = surveysData.values.slice(1).map(row => ({
            survey_id: row[0] || '',
            officer_id: row[1] || '',
            officer_name: row[2] || '',
            start_time: row[3] || '',
            end_time: row[4] || '',
            start_lat: parseFloat(row[5]) || 0,
            start_lng: parseFloat(row[6]) || 0,
            end_lat: parseFloat(row[7]) || 0,
            end_lng: parseFloat(row[8]) || 0,
            duration_minutes: parseInt(row[9]) || 0,
            status: row[10] || ''
        })).filter(survey => {
            const surveyDate = new Date(survey.start_time).toISOString().split('T')[0];
            const inDateRange = (!dateFrom || surveyDate >= dateFrom) && (!dateTo || surveyDate <= dateTo);
            const matchesPetugas = !selectedPetugas || survey.officer_id === selectedPetugas;
            return inDateRange && matchesPetugas;
        });
    }
    
    // Process tracking logs (skip header row)
    if (trackingData.values && trackingData.values.length > 1) {
        trackingData = trackingData.values.slice(1).map(row => ({
            timestamp: row[0] || '',
            officer_id: row[1] || '',
            survey_id: row[2] || '',
            latitude: parseFloat(row[3]) || 0,
            longitude: parseFloat(row[4]) || 0,
            accuracy: parseFloat(row[5]) || 0,
            type: row[6] || ''
        })).filter(track => {
            const trackDate = new Date(track.timestamp).toISOString().split('T')[0];
            const inDateRange = (!dateFrom || trackDate >= dateFrom) && (!dateTo || trackDate <= dateTo);
            const matchesPetugas = !selectedPetugas || track.officer_id === selectedPetugas;
            return inDateRange && matchesPetugas;
        });
    }
    
    // Process photos (skip header row)
    if (photosData.values && photosData.values.length > 1) {
        photosData = photosData.values.slice(1).map(row => ({
            photo_id: row[0] || '',
            survey_id: row[1] || '',
            officer_id: row[2] || '',
            timestamp: row[3] || '',
            latitude: parseFloat(row[4]) || 0,
            longitude: parseFloat(row[5]) || 0,
            photo_path: row[6] || '',
            description: row[7] || ''
        })).filter(photo => {
            const photoDate = new Date(photo.timestamp).toISOString().split('T')[0];
            const inDateRange = (!dateFrom || photoDate >= dateFrom) && (!dateTo || photoDate <= dateTo);
            const matchesPetugas = !selectedPetugas || photo.officer_id === selectedPetugas;
            return inDateRange && matchesPetugas;
        });
    }
    
    console.log('Real data loaded:', { surveysData, trackingData, photosData });
}

// Load demo data
async function loadDemoData() {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    const dateFrom = document.getElementById('dateFrom').value;
    const dateTo = document.getElementById('dateTo').value;
    
    // Generate demo tracking data
    trackingData = generateDemoTrackingData(selectedPetugas, dateFrom, dateTo);
    
    // Generate demo surveys data
    surveysData = generateDemoSurveysData(selectedPetugas, dateFrom, dateTo);
    
    // Generate demo photos data
    photosData = generateDemoPhotosData(selectedPetugas, dateFrom, dateTo);
}

// Generate demo tracking data
function generateDemoTrackingData(petugasFilter, dateFrom, dateTo) {
    const data = [];
    const startDate = new Date(dateFrom || '2024-01-01');
    const endDate = new Date(dateTo || '2024-12-31');
    
    // Labuhanbatu Utara area coordinates
    const labuhanbatuBounds = {
        north: 2.45,
        south: 2.20,
        east: 99.95,
        west: 99.75
    };
    
    const petugasList = petugasFilter ? [petugasFilter] : 
        Array.from({length: 5}, (_, i) => `PET${(i + 1).toString().padStart(3, '0')}`);
    
    petugasList.forEach((petugasId, petugasIndex) => {
        // Generate 3-5 surveys per petugas
        const surveyCount = Math.floor(Math.random() * 3) + 3;
        
        for (let s = 0; s < surveyCount; s++) {
            const surveyId = `${petugasId}_${Date.now()}_${s}`;
            const surveyDate = new Date(startDate.getTime() + Math.random() * (endDate.getTime() - startDate.getTime()));
            
            // Generate route points (10-20 points per survey)
            const pointCount = Math.floor(Math.random() * 11) + 10;
            let currentLat = labuhanbatuBounds.south + Math.random() * (labuhanbatuBounds.north - labuhanbatuBounds.south);
            let currentLng = labuhanbatuBounds.west + Math.random() * (labuhanbatuBounds.east - labuhanbatuBounds.west);
            
            for (let p = 0; p < pointCount; p++) {
                // Simulate movement (small random walk)
                currentLat += (Math.random() - 0.5) * 0.01;
                currentLng += (Math.random() - 0.5) * 0.01;
                
                // Keep within Labuhanbatu Utara bounds
                currentLat = Math.max(labuhanbatuBounds.south, Math.min(labuhanbatuBounds.north, currentLat));
                currentLng = Math.max(labuhanbatuBounds.west, Math.min(labuhanbatuBounds.east, currentLng));
                
                const timestamp = new Date(surveyDate.getTime() + p * 30000); // 30 seconds apart
                
                data.push({
                    timestamp: timestamp.toISOString(),
                    officer_id: petugasId,
                    survey_id: surveyId,
                    latitude: currentLat,
                    longitude: currentLng,
                    accuracy: Math.random() * 10 + 5,
                    type: p === 0 ? 'start' : (p === pointCount - 1 ? 'end' : 'auto_tracking')
                });
            }
        }
    });
    
    return data;
}

// Generate demo surveys data
function generateDemoSurveysData(petugasFilter, dateFrom, dateTo) {
    const data = [];
    const uniqueSurveys = [...new Set(trackingData.map(t => t.survey_id))];
    
    uniqueSurveys.forEach(surveyId => {
        const surveyPoints = trackingData.filter(t => t.survey_id === surveyId);
        if (surveyPoints.length === 0) return;
        
        const startPoint = surveyPoints[0];
        const endPoint = surveyPoints[surveyPoints.length - 1];
        const duration = Math.floor(Math.random() * 120) + 30; // 30-150 minutes
        
        data.push({
            survey_id: surveyId,
            officer_id: startPoint.officer_id,
            officer_name: `Petugas ${startPoint.officer_id.slice(-2)}`,
            start_time: startPoint.timestamp,
            end_time: endPoint.timestamp,
            start_lat: startPoint.latitude,
            start_lng: startPoint.longitude,
            end_lat: endPoint.latitude,
            end_lng: endPoint.longitude,
            duration_minutes: duration,
            status: 'completed'
        });
    });
    
    return data;
}

// Generate demo photos data
function generateDemoPhotosData(petugasFilter, dateFrom, dateTo) {
    const data = [];
    const photoUrls = [
        'https://via.placeholder.com/300x200/FF6B6B/FFFFFF?text=Survey+Photo+1',
        'https://via.placeholder.com/300x200/4ECDC4/FFFFFF?text=Survey+Photo+2',
        'https://via.placeholder.com/300x200/45B7D1/FFFFFF?text=Survey+Photo+3',
        'https://via.placeholder.com/300x200/96CEB4/FFFFFF?text=Survey+Photo+4',
        'https://via.placeholder.com/300x200/FFEAA7/FFFFFF?text=Survey+Photo+5'
    ];
    
    // Generate 2-3 photos per survey
    surveysData.forEach(survey => {
        const photoCount = Math.floor(Math.random() * 2) + 2;
        
        for (let i = 0; i < photoCount; i++) {
            const surveyPoints = trackingData.filter(t => t.survey_id === survey.survey_id);
            const randomPoint = surveyPoints[Math.floor(Math.random() * surveyPoints.length)];
            
            data.push({
                photo_id: `${survey.survey_id}_photo_${i}`,
                survey_id: survey.survey_id,
                officer_id: survey.officer_id,
                timestamp: randomPoint.timestamp,
                latitude: randomPoint.latitude,
                longitude: randomPoint.longitude,
                photo_url: photoUrls[i % photoUrls.length],
                description: `Foto survey ${i + 1} - ${survey.officer_name}`
            });
        }
    });
    
    return data;
}

// Show routes on map
function showRoutes() {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    
    // Group tracking data by survey
    const surveyGroups = {};
    trackingData.forEach(point => {
        if (!selectedPetugas || point.officer_id === selectedPetugas) {
            if (!surveyGroups[point.survey_id]) {
                surveyGroups[point.survey_id] = [];
            }
            surveyGroups[point.survey_id].push(point);
        }
    });
    
    // Draw routes for each survey
    Object.keys(surveyGroups).forEach((surveyId, index) => {
        const points = surveyGroups[surveyId].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
        const color = petugasColors[index % petugasColors.length];
        
        // Create polyline for route
        const coordinates = points.map(p => [p.latitude, p.longitude]);
        const polyline = L.polyline(coordinates, {
            color: color,
            weight: 3,
            opacity: 0.7
        }).addTo(map);
        
        routeLayers.push(polyline);
        
        // Add start marker
        if (points.length > 0) {
            const startPoint = points[0];
            const startMarker = L.circleMarker([startPoint.latitude, startPoint.longitude], {
                color: '#44ff44',
                fillColor: '#44ff44',
                fillOpacity: 0.8,
                radius: 8
            }).addTo(map);
            
            startMarker.bindPopup(`
                <b>🚀 Start Survey</b><br>
                Petugas: ${startPoint.officer_id}<br>
                Waktu: ${new Date(startPoint.timestamp).toLocaleString('id-ID')}<br>
                Koordinat: ${startPoint.latitude.toFixed(6)}, ${startPoint.longitude.toFixed(6)}
            `);
            
            routeLayers.push(startMarker);
        }
        
        // Add end marker
        if (points.length > 1) {
            const endPoint = points[points.length - 1];
            const endMarker = L.circleMarker([endPoint.latitude, endPoint.longitude], {
                color: '#4444ff',
                fillColor: '#4444ff',
                fillOpacity: 0.8,
                radius: 8
            }).addTo(map);
            
            endMarker.bindPopup(`
                <b>🏁 End Survey</b><br>
                Petugas: ${endPoint.officer_id}<br>
                Waktu: ${new Date(endPoint.timestamp).toLocaleString('id-ID')}<br>
                Koordinat: ${endPoint.latitude.toFixed(6)}, ${endPoint.longitude.toFixed(6)}
            `);
            
            routeLayers.push(endMarker);
        }
        
        // Bind popup to polyline
        polyline.bindPopup(`
            <b>📍 Jalur Survey</b><br>
            Survey ID: ${surveyId}<br>
            Petugas: ${points[0].officer_id}<br>
            Total Points: ${points.length}<br>
            Durasi: ${Math.round((new Date(points[points.length-1].timestamp) - new Date(points[0].timestamp)) / 60000)} menit
        `);
    });
    
    // Fit map to show all routes
    if (routeLayers.length > 0) {
        const group = new L.featureGroup(routeLayers);
        map.fitBounds(group.getBounds().pad(0.1));
    }
}

// Show heatmap
function showHeatmap() {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    
    // Prepare heatmap data
    const heatmapData = trackingData
        .filter(point => !selectedPetugas || point.officer_id === selectedPetugas)
        .map(point => [point.latitude, point.longitude, 1]);
    
    if (heatmapData.length > 0) {
        heatmapLayer = L.heatLayer(heatmapData, {
            radius: 25,
            blur: 15,
            maxZoom: 17,
            gradient: {
                0.0: 'blue',
                0.2: 'cyan',
                0.4: 'lime',
                0.6: 'yellow',
                0.8: 'orange',
                1.0: 'red'
            }
        }).addTo(map);
        
        // Fit map to heatmap bounds
        const bounds = L.latLngBounds(heatmapData.map(point => [point[0], point[1]]));
        map.fitBounds(bounds.pad(0.1));
    }
}

// Show photos on map
function showPhotos() {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    
    photosData
        .filter(photo => !selectedPetugas || photo.officer_id === selectedPetugas)
        .forEach((photo, index) => {
            const marker = L.marker([photo.latitude, photo.longitude], {
                icon: L.divIcon({
                    className: 'photo-marker',
                    html: '📷',
                    iconSize: [25, 25],
                    iconAnchor: [12, 12]
                })
            }).addTo(map);
            
            marker.bindPopup(`
                <div class="photo-popup">
                    <img src="${photo.photo_url}" alt="Survey Photo">
                    <div class="photo-info">
                        <b>${photo.description}</b><br>
                        Petugas: ${photo.officer_id}<br>
                        Waktu: ${new Date(photo.timestamp).toLocaleString('id-ID')}<br>
                        Koordinat: ${photo.latitude.toFixed(6)}, ${photo.longitude.toFixed(6)}
                    </div>
                </div>
            `);
            
            photoMarkers.push(marker);
        });
    
    // Fit map to show all photos
    if (photoMarkers.length > 0) {
        const group = new L.featureGroup(photoMarkers);
        map.fitBounds(group.getBounds().pad(0.1));
    }
}

// Clear all layers
function clearLayers() {
    routeLayers.forEach(layer => map.removeLayer(layer));
    routeLayers = [];
    
    if (heatmapLayer) {
        map.removeLayer(heatmapLayer);
        heatmapLayer = null;
    }
    
    photoMarkers.forEach(marker => map.removeLayer(marker));
    photoMarkers = [];
}

// Update statistics
function updateStats() {
    const selectedPetugas = document.getElementById('petugasSelect').value;
    
    const filteredSurveys = surveysData.filter(s => !selectedPetugas || s.officer_id === selectedPetugas);
    const filteredPhotos = photosData.filter(p => !selectedPetugas || p.officer_id === selectedPetugas);
    const activePetugas = [...new Set(filteredSurveys.map(s => s.officer_id))].length;
    
    // Calculate total distance
    let totalDistance = 0;
    const surveyGroups = {};
    trackingData.forEach(point => {
        if (!selectedPetugas || point.officer_id === selectedPetugas) {
            if (!surveyGroups[point.survey_id]) {
                surveyGroups[point.survey_id] = [];
            }
            surveyGroups[point.survey_id].push(point);
        }
    });
    
    Object.values(surveyGroups).forEach(points => {
        points.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
        for (let i = 1; i < points.length; i++) {
            const dist = calculateDistance(
                points[i-1].latitude, points[i-1].longitude,
                points[i].latitude, points[i].longitude
            );
            totalDistance += dist;
        }
    });
    
    document.getElementById('totalSurveys').textContent = filteredSurveys.length;
    document.getElementById('activePetugas').textContent = activePetugas;
    document.getElementById('totalPhotos').textContent = filteredPhotos.length;
    document.getElementById('totalDistance').textContent = `${totalDistance.toFixed(1)} km`;
}

// Calculate distance between two points (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
}

// Export data to Excel (placeholder)
function exportData() {
    alert('Fitur export Excel akan segera tersedia!\n\nData yang akan diekspor:\n- Survey logs\n- Tracking data\n- Photo locations\n- Statistics summary');
}

// Show/hide loading
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

// Event listeners
document.getElementById('viewMode').addEventListener('change', loadData);
document.getElementById('petugasSelect').addEventListener('change', loadData);
document.getElementById('dateFrom').addEventListener('change', loadData);
document.getElementById('dateTo').addEventListener('change', loadData);

// Initialize when page loads
document.addEventListener('DOMContentLoaded', initMap);
