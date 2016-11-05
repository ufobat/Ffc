Coding decisions
================

Eine kleine Zusammenfassung von Ansprüchen, die ich implementationsseitig an das Projekt stelle:

* Das Forum soll eine geschlossene Plattform sein
    * Sicherheit steht an erster Stelle
    * Vertraulichkeit steht an zweiter Stelle
    * Jede Code-und Feature-Entscheidung muss dem unterstellt werden
    * Ohne Anmeldung dürfen keine Dateninhalte nach aussen gereicht werden
        * Keine Emails mit Beitrags-Inhalten
        * Keine Benutzerdetails
    * Benutzer müssen sich immer anmelden
        * Benutzer können sich nicht selber registrieren, müssen bewusst von einem Admin eingerichtet werden
* Javascript ohne Fremdbibliotheken
    * Moderne Browser unterstützen inhaltlich alle Notwendigkeiten
    * Grafische fancy Features sind nicht geplant
    * Idee: Handcrafted als Überung für das Verstädnis der Vorgänge für REST und responsive Design
* Jedes Feature und jeder Bug erhalten eine umfangreiche Testsuite vor dem Release
    * Test-Bibliotheken für komplexe generische Tests
* Generisches Handling von Beiträgen
    * Beitrags-Handling als einheitliches Plugin implementiert
* Deployment erfolgt als Instanz in einem einzigen Verzeichnis
    * SQLite-Datenbank, um auf extern konfigurierte Datenbank-Services und Instanz-Verzeichnisse zu verzichten
    * Ein Verzeichnis enthält alle Daten einer Foreninstanz und kann so einfach verschoben oder gebackupt werden
    * Eine Software-Instalation kann für mehrere Instanzen (einzelne Foren) verwendet werden, die einzelnen Foren dürfen aber keinesfalls miteinander interagieren können
* Klares HTML-Design, keine komplexen Schachteln
* Geschwindigkeit in Auslieferung und Darstellung stehen ebenfalls mit auf der Liste der Ziele

