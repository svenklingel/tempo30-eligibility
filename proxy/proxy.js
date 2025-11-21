// Acts as a proxy between GeoServer WFS and the browser to bypass CORS restrictions
const express = require('express');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const app = express();

const GEOSERVER_BASE_URL = 'http://localhost:8082/geoserver';
const WORKSPACE = 'roads_ws';
const OUTPUT_FORMAT = 'application/json';
const SRS_NAME = 'EPSG:4326';

// CORS-Middleware hinzufügen
app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

/**
 * Proxy-Endpunkt für den Layer ne:tempo30_analyse_ergebnis
 */
app.get('/tempo30-wfs', async (req, res) => {
    const layerName = 'eligable_roads';
    try {
        const url = `${GEOSERVER_BASE_URL}/${WORKSPACE}/wfs?service=WFS&version=2.0.0&request=GetFeature&typeName=${WORKSPACE}:${layerName}&outputFormat=${OUTPUT_FORMAT}&srsName=${SRS_NAME}`;
        
        console.log(`Abrufen von URL: ${url}`);
        const response = await fetch(url);
        
        // Überprüfen, ob die Antwort erfolgreich war (Status 200)
        if (!response.ok) {
            console.error(`GeoServer-Fehler (${response.status}): ${response.statusText}`);
            return res.status(response.status).send(`Fehler von GeoServer: ${response.statusText}`);
        }
        
        const data = await response.text();
        res.setHeader('Content-Type', OUTPUT_FORMAT);
        res.send(data);
    } catch (error) {
        console.error('Fehler beim Abrufen der WFS-Daten für Tempo 30:', error);
        res.status(500).send('Fehler beim Abrufen der Daten für Tempo 30 Analyse');
    }
});

/**
 * Proxy-Endpunkt für den Layer roads_store:planet_osm_roads
 */
app.get('/roads-wfs', async (req, res) => {
    const layerName = 'planet_osm_roads';
    try {
        const url = `${GEOSERVER_BASE_URL}/${WORKSPACE}/wfs?service=WFS&version=2.0.0&request=GetFeature&typeName=${WORKSPACE}:${layerName}&outputFormat=${OUTPUT_FORMAT}&srsName=${SRS_NAME}`;
        
        console.log(`Abrufen von URL: ${url}`);
        const response = await fetch(url);

        // Überprüfen, ob die Antwort erfolgreich war (Status 200)
        if (!response.ok) {
            console.error(`GeoServer-Fehler (${response.status}): ${response.statusText}`);
            return res.status(response.status).send(`Fehler von GeoServer: ${response.statusText}`);
        }
        
        const data = await response.text();
        res.setHeader('Content-Type', OUTPUT_FORMAT);
        res.send(data);
    } catch (error) {
        console.error('Fehler beim Abrufen der WFS-Daten für Roads:', error);
        res.status(500).send('Fehler beim Abrufen der Daten für OSM Roads');
    }
});

app.listen(3000, () => 
    console.log('Proxy läuft auf http://localhost:3000/tempo30-wfs und http://localhost:3000/roads-wfs')
);