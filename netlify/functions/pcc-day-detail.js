// pcc-day-detail.js - Per-day hourly detail endpoint
// Returns hourly breakdown of PCC trolleys for a specific date

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

export const handler = async (event) => {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=600' // Cache 10 min (historical data is stable)
    };

    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers, body: '' };
    }

    const date = (event.queryStringParameters || {}).date;
    if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
        return {
            statusCode: 400,
            headers,
            body: JSON.stringify({ error: 'date parameter required (YYYY-MM-DD)' })
        };
    }

    try {
        // Query PCC observations for the given date (Eastern time boundaries).
        // Offset must follow daylight saving; it was hardcoded -05:00 until 2026-08-25.
        const offset = easternOffset(new Date(`${date}T12:00:00Z`));
        const startOfDay = `${date}T00:00:00${offset}`;
        const endOfDay = `${date}T23:59:59${offset}`;

        const { data: observations, error } = await supabase
            .from('pcc_observations')
            .select('observed_at, vehicle_id, direction, late_minutes')
            .gte('observed_at', startOfDay)
            .lte('observed_at', endOfDay)
            .or('vehicle_type.eq.pcc,vehicle_type.is.null')
            .order('observed_at', { ascending: true })
            .limit(5000);

        if (error) throw error;

        if (!observations || observations.length === 0) {
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({
                    date,
                    totalObservations: 0,
                    hourlyBreakdown: [],
                    vehicleTimelines: []
                })
            };
        }

        // Build hourly breakdown and per-vehicle timelines
        const hourlyMap = {};
        const vehicleMap = {};

        for (const obs of observations) {
            // Keep the real UTC instant; formatTime applies the Eastern zone once.
            // Re-parsing toLocaleString output here double-shifted times by 4 hours until 2026-08-25.
            const dt = new Date(obs.observed_at);
            const hour = easternHour(dt);

            // Hourly grouping
            if (!hourlyMap[hour]) {
                hourlyMap[hour] = { vehicles: new Set(), count: 0 };
            }
            hourlyMap[hour].vehicles.add(obs.vehicle_id);
            hourlyMap[hour].count++;

            // Per-vehicle timeline
            if (!vehicleMap[obs.vehicle_id]) {
                vehicleMap[obs.vehicle_id] = {
                    firstSeen: dt,
                    lastSeen: dt,
                    hours: new Set(),
                    observations: 0,
                    directionSequence: [] // for trip counting
                };
            }
            vehicleMap[obs.vehicle_id].lastSeen = dt;
            vehicleMap[obs.vehicle_id].hours.add(hour);
            vehicleMap[obs.vehicle_id].observations++;
            vehicleMap[obs.vehicle_id].directionSequence.push({
                direction: obs.direction, time: dt
            });
        }

        // Format hourly breakdown (all 24 hours)
        const hourlyBreakdown = [];
        for (let h = 0; h < 24; h++) {
            const data = hourlyMap[h];
            hourlyBreakdown.push({
                hour: h,
                label: formatHour(h),
                vehicleCount: data ? data.vehicles.size : 0,
                vehicles: data ? Array.from(data.vehicles) : [],
                observations: data ? data.count : 0
            });
        }

        // Count trips per vehicle from direction sequences
        // A trip = one continuous run in one direction. Direction change or >30 min gap = new trip.
        function countVehicleTrips(dirSeq) {
            let ebTrips = 0, wbTrips = 0;
            let lastDir = null, lastTime = null;
            for (const entry of dirSeq) {
                const gap = lastTime ? (entry.time - lastTime) / (1000 * 60) : 0;
                if (entry.direction !== lastDir || gap > 30) {
                    if (entry.direction === 'Eastbound') ebTrips++;
                    else if (entry.direction === 'Westbound') wbTrips++;
                    lastDir = entry.direction;
                }
                lastTime = entry.time;
            }
            return { ebTrips, wbTrips, trips: ebTrips + wbTrips };
        }

        // Format vehicle timelines
        let totalEbTrips = 0, totalWbTrips = 0;
        const vehicleTimelines = Object.entries(vehicleMap)
            .map(([id, data]) => {
                const tripCounts = countVehicleTrips(data.directionSequence);
                totalEbTrips += tripCounts.ebTrips;
                totalWbTrips += tripCounts.wbTrips;
                return {
                    vehicleId: id,
                    firstSeen: formatTime(data.firstSeen),
                    lastSeen: formatTime(data.lastSeen),
                    hoursActive: Array.from(data.hours).sort((a, b) => a - b),
                    observations: data.observations,
                    trips: tripCounts.trips,
                    ebTrips: tripCounts.ebTrips,
                    wbTrips: tripCounts.wbTrips
                };
            })
            .sort((a, b) => {
                const aFirst = a.hoursActive[0] || 0;
                const bFirst = b.hoursActive[0] || 0;
                return aFirst - bFirst;
            });

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                date,
                totalObservations: observations.length,
                ebTrips: totalEbTrips,
                wbTrips: totalWbTrips,
                totalTrips: totalEbTrips + totalWbTrips,
                hourlyBreakdown,
                vehicleTimelines
            })
        };

    } catch (error) {
        console.error('Day detail error:', error);
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ error: error.message })
        };
    }
};

// Eastern hour (0-23) of a real UTC Date. Intl does the zone math, so daylight
// saving is handled and no fake locally-parsed Date is involved (2026-08-25).
function easternHour(date) {
    return Number(new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/New_York',
        hour: 'numeric',
        hourCycle: 'h23'
    }).format(date));
}

// UTC offset string ("-04:00" or "-05:00") for Eastern time on the given date.
// Same technique as push-status.js. Noon UTC is always the requested calendar
// day in Eastern, so the offset matches the day being queried (2026-08-25).
function easternOffset(date) {
    const parts = new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/New_York',
        timeZoneName: 'shortOffset'
    }).formatToParts(date);
    const tz = (parts.find(p => p.type === 'timeZoneName') || {}).value || 'GMT-5';
    const m = tz.match(/GMT([+-]\d+)/);
    const hours = m ? parseInt(m[1], 10) : -5;
    const sign = hours < 0 ? '-' : '+';
    return `${sign}${String(Math.abs(hours)).padStart(2, '0')}:00`;
}

function formatHour(hour) {
    if (hour === 0 || hour === 24) return '12am';
    if (hour === 12) return '12pm';
    if (hour < 12) return `${hour}am`;
    return `${hour - 12}pm`;
}

function formatTime(date) {
    return date.toLocaleTimeString('en-US', {
        timeZone: 'America/New_York',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
    });
}
