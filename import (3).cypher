// =============================================================================
// HAUSRAT-WISSENSGRAPH v3
// =============================================================================
// Aenderungen gegenueber v2:
//   - Ausschluesse haengen an Bausteinen (nicht mehr am Vertrag)
//   - Generelle Ausschluesse (Krieg, Kern, Innere Unruhen) haengen an ALLEN
//     Bausteinen gleichzeitig
//   - Neuer Knotentyp NichtHausrat (was laut A 9 nicht versichert ist)
//
// VOR dem Ausfuehren: DEIN-USER/DEIN-REPO durch deinen Pfad ersetzen
// =============================================================================


// 1) Constraints
CREATE CONSTRAINT vertrag_id        IF NOT EXISTS FOR (n:Vertrag)               REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT baustein_id       IF NOT EXISTS FOR (n:Deckungsbaustein)      REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT gefahr_id         IF NOT EXISTS FOR (n:Gefahr)                REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT ausschluss_id     IF NOT EXISTS FOR (n:Ausschluss)            REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT chunk_id          IF NOT EXISTS FOR (n:TextChunk)             REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT sache_id          IF NOT EXISTS FOR (n:VersicherteSache)      REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT grenze_id         IF NOT EXISTS FOR (n:Entschaedigungsgrenze) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT nichthausrat_id   IF NOT EXISTS FOR (n:NichtHausrat)          REQUIRE n.id IS UNIQUE;


// 2) Knoten laden

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/vertrag.csv' AS row
MERGE (n:Vertrag {id: row.id})
SET n.name = row.name, n.modell = row.modell, n.stand = row.stand;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/bausteine.csv' AS row
MERGE (n:Deckungsbaustein {id: row.id})
SET n.name = row.name, n.art = row.art, n.paragraph = row.paragraph;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/gefahren.csv' AS row
MERGE (n:Gefahr {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/ausschluesse.csv' AS row
MERGE (n:Ausschluss {id: row.id})
SET n.name = row.name, n.art = row.art, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/textchunks.csv' AS row
MERGE (n:TextChunk {id: row.id})
SET n.paragraph = row.paragraph, n.titel = row.titel, n.text = row.text;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/grenzen.csv' AS row
MERGE (n:Entschaedigungsgrenze {id: row.id})
SET n.name = row.name,
    n.einheit = row.einheit,
    n.betrag_eur = CASE WHEN row.betrag_eur = '' THEN null ELSE toFloat(row.betrag_eur) END,
    n.prozent_vs = CASE WHEN row.prozent_vs = '' THEN null ELSE toFloat(row.prozent_vs) END,
    n.paragraph = row.paragraph;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/sachen.csv' AS row
MERGE (n:VersicherteSache {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/nicht_hausrat.csv' AS row
MERGE (n:NichtHausrat {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;


// 3) Beziehungen aufbauen

// Vertrag -> Bausteine
MATCH (v:Vertrag), (b:Deckungsbaustein)
MERGE (v)-[:HAT_BAUSTEIN]->(b);

// Bausteine -> Gefahren
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/gefahren.csv' AS row
MATCH (b:Deckungsbaustein {id: row.baustein_id})
MATCH (g:Gefahr {id: row.id})
MERGE (b)-[:ENTHAELT_GEFAHR]->(g);

// Spezielle Ausschluesse direkt an den angegebenen Baustein
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/ausschluesse.csv' AS row
WITH row WHERE row.baustein_id <> 'ALLE'
MATCH (b:Deckungsbaustein {id: row.baustein_id})
MATCH (a:Ausschluss {id: row.id})
MERGE (b)-[:SCHLIESST_AUS]->(a);

// Generelle Ausschluesse an JEDEN Baustein haengen
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/ausschluesse.csv' AS row
WITH row WHERE row.baustein_id = 'ALLE'
MATCH (b:Deckungsbaustein)
MATCH (a:Ausschluss {id: row.id})
MERGE (b)-[:SCHLIESST_AUS]->(a);

// Belege
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/textchunks.csv' AS row
MATCH (n) WHERE n.id = row.gehoert_zu_id
MATCH (t:TextChunk {id: row.id})
MERGE (n)-[:BELEGT_DURCH]->(t);

// Sachen -> Grenzen
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/sachen.csv' AS row
WITH row WHERE row.grenze_id <> ''
MATCH (s:VersicherteSache {id: row.id})
MATCH (g:Entschaedigungsgrenze {id: row.grenze_id})
MERGE (s)-[:HAT_GRENZE]->(g);

// Sachen -> Vertrag
MATCH (v:Vertrag), (s:VersicherteSache)
MERGE (s)-[:GEHOERT_ZU]->(v);

// NichtHausrat -> Vertrag
MATCH (v:Vertrag), (n:NichtHausrat)
MERGE (n)-[:NICHT_TEIL_VON]->(v);

// Alten direkten Ausschluss-Link vom Vertrag loeschen (Aufraeumen von v2)
MATCH (v:Vertrag)-[r:SCHLIESST_AUS]->()
DELETE r;


// 4) Verifikation
MATCH (n) RETURN labels(n)[0] AS typ, count(*) AS anzahl ORDER BY typ;
MATCH ()-[r]->() RETURN type(r) AS beziehung, count(*) AS anzahl ORDER BY beziehung;


// 5) Probefragen

// Welche Ausschluesse hat der Leitungswasser-Baustein?
MATCH (b:Deckungsbaustein {id:'B-LEITUNGSWASSER'})-[:SCHLIESST_AUS]->(a:Ausschluss)
RETURN b.name AS baustein, a.name AS ausschluss, a.paragraph AS quelle
ORDER BY a.paragraph;

// Generelle Ausschluesse - bei welchen Bausteinen tauchen sie auf?
MATCH (b:Deckungsbaustein)-[:SCHLIESST_AUS]->(a:Ausschluss {art:'generell'})
RETURN a.name AS ausschluss, collect(b.name) AS gilt_fuer;

// Was gehoert nicht zum Hausrat?
MATCH (n:NichtHausrat)
RETURN n.name, n.paragraph, n.beschreibung ORDER BY n.paragraph;
