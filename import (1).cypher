// =============================================================================
// HAUSRAT-WISSENSGRAPH MINIMAL
// =============================================================================
// 5 Knotentypen, 4 Beziehungen, 5 CSV-Dateien.
// In Aura: Workspace -> Query -> alles hier reinkopieren -> Strg+Enter.
//
// VOR dem Ausfuehren: ueberall DEIN-USER/DEIN-REPO durch deinen GitHub-Pfad
// ersetzen, z.B. ExuPex/graphrag.
// =============================================================================


// 1) Constraints (machen den Import sauber wiederholbar)
CREATE CONSTRAINT vertrag_id      IF NOT EXISTS FOR (n:Vertrag)          REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT baustein_id     IF NOT EXISTS FOR (n:Deckungsbaustein) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT gefahr_id       IF NOT EXISTS FOR (n:Gefahr)           REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT ausschluss_id   IF NOT EXISTS FOR (n:Ausschluss)       REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT chunk_id        IF NOT EXISTS FOR (n:TextChunk)        REQUIRE n.id IS UNIQUE;


// 2) Knoten laden (5 LOAD-Bloecke, einer pro CSV)

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


// 3) Beziehungen aufbauen

// Vertrag -[:HAT_BAUSTEIN]-> Deckungsbaustein
MATCH (v:Vertrag), (b:Deckungsbaustein)
MERGE (v)-[:HAT_BAUSTEIN]->(b);

// Deckungsbaustein -[:ENTHAELT_GEFAHR]-> Gefahr (anhand baustein_id-Spalte in gefahren.csv)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/gefahren.csv' AS row
MATCH (b:Deckungsbaustein {id: row.baustein_id})
MATCH (g:Gefahr {id: row.id})
MERGE (b)-[:ENTHAELT_GEFAHR]->(g);

// Vertrag -[:SCHLIESST_AUS]-> Ausschluss (alle Ausschluesse haengen am Vertrag)
MATCH (v:Vertrag), (a:Ausschluss)
MERGE (v)-[:SCHLIESST_AUS]->(a);

// Knoten -[:BELEGT_DURCH]-> TextChunk (anhand gehoert_zu_id in textchunks.csv)
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/DEIN-USER/DEIN-REPO/main/textchunks.csv' AS row
MATCH (n) WHERE n.id = row.gehoert_zu_id
MATCH (t:TextChunk {id: row.id})
MERGE (n)-[:BELEGT_DURCH]->(t);


// 4) Verifikation - das sollte passen:
// Vertrag=1, Deckungsbaustein=5, Gefahr=13, Ausschluss=6, TextChunk=19
MATCH (n) RETURN labels(n)[0] AS typ, count(*) AS anzahl ORDER BY typ;

// Beziehungen: HAT_BAUSTEIN=5, ENTHAELT_GEFAHR=13, SCHLIESST_AUS=6, BELEGT_DURCH=19
MATCH ()-[r]->() RETURN type(r) AS beziehung, count(*) AS anzahl ORDER BY beziehung;


// 5) Probefrage: Welche Gefahren gehoeren zum Feuer-Baustein?
MATCH (b:Deckungsbaustein {id:'B-FEUER'})-[:ENTHAELT_GEFAHR]->(g:Gefahr)
OPTIONAL MATCH (g)-[:BELEGT_DURCH]->(t:TextChunk)
RETURN g.name, g.paragraph, t.text;
