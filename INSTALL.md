Installation
============

Systemvoraussetzungen
---------------------

Folgende Software muss zunächst systemseitig zur Verfügung stehen:

* Perl Version 5.014 oder höher
* Perl-Modul Mojolicious 6.0 oder höher
* Perl-Modul DBI Version 1.63 oder höher
* Perl-Modul DBD::SQLite Version 1.4 oder höher
* SQLite Version 3.7.3 oder höher

Softwareinstallation Ffc
------------------------

Die Software muss in ein Verzeichnis ausgecheckt oder kopiert werden, in dem der Webserver ausführenden Zugriff auf die `Datei script/ffc` sowie lesenden Zugriff auf die Dateien unterhalb der Verzeichnisse `lib`, `public` und `templates` erhält. In diesem Verzeichnis befinden sich die Programmdateien der Software für alle Instanzen des Systems.

Installation einer neuen Instanz (eines eigenständigen Forums)
--------------------------------------------------------------

Verzeichnis für das Forum anlegen und für Webserver zugänglich machen:

```
$ mkdir "Forenpfad"; chmod 750 "Forenpfad"; chown "Webserveruser:Webservergruppe" "Forenpfad"
```

Verzeichnis für das Forum vorbereiten (dieses Kommando liefert am Ende die Daten für den ersten Administratorenaccount, also Benutzername "admin" und zugehöriges zufälliges Passwort):

```
$ FFC_DATA_PATH="Forenpfad" "script/init.pl" "Cookie-Name"
```

Den Webserver so konfigurieren, dass er mit der entsprechenden Pfadvariable `FFC_DATA_PATH="Forenpfad"` das Script `script/ffc` aufrufen kann. Im Apache kann das wie folgt aussehen:

```
<Location /forum.pl>
    SetEnv FFC_DATA_PATH Forenpfad
</Location>
ScriptAlias /forum.pl "script/ffc"
AddHandler cgi-script .pl
```

Anschließend sollte man sich mit den oben gelieferten Anmeldedaten (als "admin") am neu eingerichteten Forum anmelden und dort in den Einstellungen zumindest die Werte für den Cookie-Namen sowie dem Webseitentitel ändern, damit man mit etwaigen anderen Installationen der Software unter der selben Domain nicht in Konflikt kommt. Dann kann man auch schon die ersten echten Benutzer anlegen (wahlweise auch als Administratoren) oder weitere Foreneinstellungen (wie zum Beispiel die Hintergrundfarbe) ändern. Von einem anderen Administratorenaccount (falls einer angelegt wurde), kann der Benutzer "admin" dann auch deaktiviert werden wenn man den nicht benötigt, da der sonst auch immer in den Privatnachrichten als Ansprechpartner verfügbar ist.

Alternativ kann auch eine der anderen Möglichkeiten angewendet werden, wie man eine Mojolicious-Anwendung zum laufen bringt. Diese Information entnehmen Sie bitte der entsprechenden Mojolicious-Dokumentation oder der Dokumentation ihres Webservers. Wichtig ist nur, dass für das Funktionieren des Forums die passende Umgebungsvariable "FFC_DATA_PATH" auf das Forenverzeichnis gesetzt ist. Über diese Variable können auch mehrere Foren parallel eingerichtet werden auf einem Webserver.


Erläuterungen zur Installation einer neuen Instanz
--------------------------------------------------

Ein Verzeichnis muss angelegt werden, in dem der Webserverbenutzeraccount schreibenden Zugriff erhält. Dieses Verzeichnis ist das Arbeitsverzeichnis der Instanz. Eine Instanz ist ein in sich geschlossenes Forum mit eigener Datenhaltung und eigenen Benutzeraccounts. Die Software kann mehrere Instanzen in verschiedenen Arbeitsverzeichnissen verwalten. 

Innerhalb des Arbeitsverzeichnisses werden im Betrieb Dateien in Unterverzeichnissen abgelegt. Die Textdaten, Benutzerdaten sowie die Konfiguration erfolgt über eine SQLite-Datenbankdatei innerhalb des Arbeitsverzeichnisses.

Die Software verwendet die Umgebungsvariable **`FFC_DATA_PATH`**, um festzustellen, mit welcher Instanz sie gerade läuft und entsprechend welches Arbeitsverzeichnis sie verwenden muss. Diese Umgebungsvariable **`FFC_DATA_PATH`** muss beim Aufruf des Initialisierungsscriptes sowie beim Lauf der Software im Web auf den Pfad zum Arbeitsverzeichnis gesetzt werden. Ist die Variable nicht gesetzt, kommen entsprechende Fehlermeldungen.

Das Initialisierungsscript liegt unter `script/init.pl` und muss einmal vor Inbetriebnahme der Software aufgerufen werden mit der entsprechenden Umgebungsvariable **`FFC_DATA_PATH`**. Dabei wird im entsprechenden Arbeitsverzeichnis die Datenbank mit einer Standardkonfiguration sowie die Unterordnerstruktur angelegt.

Dem Initialisierungsscript muss als letzten Parameter ein eindeutiger Name für die Cookies übergeben werden. Das ist notwendig, falls mehrere Instanzen der Software unter einer Domain eingerichtet werden sollen.

Dem Initialisierungsscript kann zusätzlich mit `-d` vor dem letzten Parameter zusätzliche Information (Cookie-Secret, Crypt-Salt) entlockt werden bei Bedarf (Test-Suite).

Außerdem wird ein erster Administratoren-Account mit Zufallspasswort angelegt. Die Zugangsdaten werden auf der Kommandozeile beim Aufruf von `script/init.pl` ausgegeben und sollten notiert werden, da die weiterführende Konfiguration über diesen Account von statten geht.

Anschließend muss der Webserver so konfiguriert werden, dass das Script `script/ffc` mit der passenden Umgebungsvariable **`FFC_DATA_PATH`** als URL für diese Instanz im Web verfügbar ist. Diese Konfiguration ist von Webserver zu Webserver verschieden. Weitere Hinweise kann man auch im Internet in der Mojolicious-Dokumentation unter Deployment finden.

Unter der so eingerichteten URL sollte, wenn alles passt, anschließend das entsprechende Forum verfügbar sein. Hier kann man sich mit den vom `script/init.pl` gelieferten Daten anmelden und kann entsprechende weiterführende Konfigurationen (Foreneinstellungen und Benutzerverwaltung) unter dem Menüpunkt "Optionen" vornehmen.


