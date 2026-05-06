// =============================================================================
// HAUSRAT-WISSENSGRAPH v4 (bereinigt)
// =============================================================================
// Enthaelt:
//   - Alle Gefahren laut VHB
//   - Ausschluesse an Bausteinen (generelle an allen, spezielle am jeweiligen)
//   - Sturmflut/Trockenheit etc. gilt fuer B-STURM UND B-ELEMENTAR
//   - VersicherteSache + Entschaedigungsgrenze
//   - NichtHausrat mit Belegen
//   - Textchunks fuer alle relevanten Knoten
//
// VOR dem Ausfuehren: ExuPex/graphrag_new ersetzen (z.B. ExuPex/graphrag)
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

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/grenzen.csv' AS row
MERGE (n:Entschaedigungsgrenze {id: row.id})
SET n.name = row.name,
    n.einheit = row.einheit,
    n.betrag_eur = CASE WHEN row.betrag_eur = '' THEN null ELSE toFloat(row.betrag_eur) END,
    n.prozent_vs = CASE WHEN row.prozent_vs = '' THEN null ELSE toFloat(row.prozent_vs) END,
    n.paragraph = row.paragraph;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/sachen.csv' AS row
MERGE (n:VersicherteSache {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/nicht_hausrat.csv' AS row
MERGE (n:NichtHausrat {id: row.id})
SET n.name = row.name, n.paragraph = row.paragraph, n.beschreibung = row.beschreibung;


// 3) Beziehungen

// Vertrag -> Bausteine
MATCH (v:Vertrag), (b:Deckungsbaustein)
MERGE (v)-[:HAT_BAUSTEIN]->(b);

// Bausteine -> Gefahren
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/gefahren.csv' AS row
MATCH (b:Deckungsbaustein {id: row.baustein_id})
MATCH (g:Gefahr {id: row.id})
MERGE (b)-[:ENTHAELT_GEFAHR]->(g);

// Spezielle Ausschluesse: baustein_id kann mehrere mit | enthalten
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/ausschluesse.csv' AS row
WITH row WHERE row.baustein_id <> 'ALLE'
WITH row, split(row.baustein_id, '|') AS baustein_liste
UNWIND baustein_liste AS bid
MATCH (b:Deckungsbaustein {id: bid})
MATCH (a:Ausschluss {id: row.id})
MERGE (b)-[:SCHLIESST_AUS]->(a);

// Generelle Ausschluesse an alle Bausteine
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/ausschluesse.csv' AS row
WITH row WHERE row.baustein_id = 'ALLE'
MATCH (b:Deckungsbaustein)
MATCH (a:Ausschluss {id: row.id})
MERGE (b)-[:SCHLIESST_AUS]->(a);

// Belege
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/textchunks.csv' AS row
MATCH (n) WHERE n.id = row.gehoert_zu_id
MATCH (t:TextChunk {id: row.id})
MERGE (n)-[:BELEGT_DURCH]->(t);

// Sachen -> Grenzen
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/ExuPex/graphrag_new/main/sachen.csv' AS row
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

// Aufraeumen: alte direkte Ausschluss-Links vom Vertrag entfernen
MATCH (v:Vertrag)-[r:SCHLIESST_AUS]->()
DELETE r;


// 4) Verifikation
// Erwartet:
//   Vertrag=1, Deckungsbaustein=5, Gefahr=31, Ausschluss=17,
//   TextChunk=58, VersicherteSache=11, Entschaedigungsgrenze=9, NichtHausrat=7
MATCH (n) RETURN labels(n)[0] AS typ, count(*) AS anzahl ORDER BY typ;

MATCH ()-[r]->() RETURN type(r) AS beziehung, count(*) AS anzahl ORDER BY beziehung;


// 5) Probefragen

// Welche Ausschluesse gelten fuer den Elementar-Baustein?
MATCH (b:Deckungsbaustein {id:'B-ELEMENTAR'})-[:SCHLIESST_AUS]->(a:Ausschluss)
RETURN a.name, a.paragraph ORDER BY a.paragraph;

// Was gehoert nicht zum Hausrat?
MATCH (n:NichtHausrat)-[:BELEGT_DURCH]->(t:TextChunk)
RETURN n.name, t.text ORDER BY n.paragraph;
