// =============================================================================
// HAUSRAT-WISSENSGRAPH v2 - Erweitert um Sachen und Entschaedigungsgrenzen
// =============================================================================
// Stufen 1+2:
//   Stufe 1: alle Gefahren laut VHB
//   Stufe 2: VersicherteSache + Entschaedigungsgrenze als neue Knoten
//
// VOR dem Ausfuehren: ueberall ExuPex/graphrag_new durch deinen Pfad ersetzen
// (z.B. ExuPex/graphrag).
//
// Das Skript ist idempotent (MERGE) - du kannst es ueber den vorhandenen
// Graphen drueberlaufen lassen, neue Knoten kommen dazu, alte werden
// aktualisiert.
// =============================================================================


// 1) Constraints (zwei neue dazu)
CREATE CONSTRAINT vertrag_id      IF NOT EXISTS FOR (n:Vertrag)              REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT baustein_id     IF NOT EXISTS FOR (n:Deckungsbaustein)     REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT gefahr_id       IF NOT EXISTS FOR (n:Gefahr)               REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT ausschluss_id   IF NOT EXISTS FOR (n:Ausschluss)           REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT chunk_id        IF NOT EXISTS FOR (n:TextChunk)            REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT sache_id        IF NOT EXISTS FOR (n:VersicherteSache)     REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT grenze_id       IF NOT EXISTS FOR (n:Entschaedigungsgrenze) REQUIRE n.id IS UNIQUE;


// 2) Knoten laden

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/vertrag.csv' AS row
MERGE (n:Vertrag {id: row.id})
SET n.name = row.name, n.modell = row.modell, n.stand = row.stand;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/bausteine.csv' AS row
MERGE (n:Deckungsbaustein {id: row.id})
SET n.name = row.name, n.art = row.art, n.paragraph = row.paragraph;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/gefahren.csv' AS row
MERGE (n:Gefahr {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/ausschluesse.csv' AS row
MERGE (n:Ausschluss {id: row.id})
SET n.name = row.name, n.art = row.art, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/textchunks.csv' AS row
MERGE (n:TextChunk {id: row.id})
SET n.paragraph = row.paragraph, n.titel = row.titel, n.text = row.text;

// NEU: Entschaedigungsgrenzen
// Leere Zellen bei betrag_eur und prozent_vs werden zu null.
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/grenzen.csv' AS row
MERGE (n:Entschaedigungsgrenze {id: row.id})
SET n.name = row.name,
    n.einheit = row.einheit,
    n.betrag_eur = CASE WHEN row.betrag_eur = '' THEN null ELSE toFloat(row.betrag_eur) END,
    n.prozent_vs = CASE WHEN row.prozent_vs = '' THEN null ELSE toFloat(row.prozent_vs) END,
    n.paragraph = row.paragraph;

// NEU: Versicherte Sachen
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/sachen.csv' AS row
MERGE (n:VersicherteSache {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;


// 3) Beziehungen aufbauen

// Vertrag -[:HAT_BAUSTEIN]-> Deckungsbaustein
MATCH (v:Vertrag), (b:Deckungsbaustein)
MERGE (v)-[:HAT_BAUSTEIN]->(b);

// Deckungsbaustein -[:ENTHAELT_GEFAHR]-> Gefahr
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/gefahren.csv' AS row
MATCH (b:Deckungsbaustein {id: row.baustein_id})
MATCH (g:Gefahr {id: row.id})
MERGE (b)-[:ENTHAELT_GEFAHR]->(g);

// Vertrag -[:SCHLIESST_AUS]-> Ausschluss
MATCH (v:Vertrag), (a:Ausschluss)
MERGE (v)-[:SCHLIESST_AUS]->(a);

// Knoten -[:BELEGT_DURCH]-> TextChunk
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/textchunks.csv' AS row
MATCH (n) WHERE n.id = row.gehoert_zu_id
MATCH (t:TextChunk {id: row.id})
MERGE (n)-[:BELEGT_DURCH]->(t);

// NEU: VersicherteSache -[:HAT_GRENZE]-> Entschaedigungsgrenze
// Nur wenn die Sache eine grenze_id in der CSV hat.
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/sachen.csv' AS row
WITH row WHERE row.grenze_id <> ''
MATCH (s:VersicherteSache {id: row.id})
MATCH (g:Entschaedigungsgrenze {id: row.grenze_id})
MERGE (s)-[:HAT_GRENZE]->(g);

// NEU: VersicherteSache -[:GEHOERT_ZU]-> Vertrag
// Damit alle Sachen am Vertrag haengen (auch ohne expliziten Baustein).
MATCH (v:Vertrag), (s:VersicherteSache)
MERGE (s)-[:GEHOERT_ZU]->(v);


// 4) Verifikation
// Erwartet: Vertrag=1, Deckungsbaustein=5, Gefahr=31, Ausschluss=6,
//           TextChunk=29, VersicherteSache=11, Entschaedigungsgrenze=9
MATCH (n) RETURN labels(n)[0] AS typ, count(*) AS anzahl ORDER BY typ;

// Beziehungen:
// HAT_BAUSTEIN=5, ENTHAELT_GEFAHR=31, SCHLIESST_AUS=6, BELEGT_DURCH=29,
// HAT_GRENZE=8, GEHOERT_ZU=11
MATCH ()-[r]->() RETURN type(r) AS beziehung, count(*) AS anzahl ORDER BY beziehung;


// 5) Probefragen

// 5a) Welche Wertsachen haben welche Grenze?
MATCH (s:VersicherteSache)-[:HAT_GRENZE]->(lim:Entschaedigungsgrenze)
RETURN s.name AS sache, lim.name AS grenze, lim.einheit AS einheit, lim.paragraph AS quelle
ORDER BY s.name;

// 5b) Welche Gefahren sind nur optional gedeckt?
MATCH (b:Deckungsbaustein {art:'optional'})-[:ENTHAELT_GEFAHR]->(g:Gefahr)
RETURN b.name AS baustein, g.name AS gefahr, g.paragraph AS quelle
ORDER BY g.name;

// 5c) Komplettbild fuer eine konkrete Sache (Beispiel: Schmuck)
MATCH (s:VersicherteSache {id:'S-SCHMUCK'})
OPTIONAL MATCH (s)-[:HAT_GRENZE]->(lim:Entschaedigungsgrenze)
OPTIONAL MATCH (s)-[:BELEGT_DURCH]->(t:TextChunk)
RETURN s.name, lim.name AS grenze, t.text AS belegtext;
