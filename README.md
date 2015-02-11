Ffc
===

Schnelle, leichtgewichtige, übersichtliche, schlanke und 
unkomplizierte Foren- und Nachrichtenplattform für eine 
überschaubare Anzahl von händisch angelegten angemeldeten 
Teilnehmern mit klarer und einfacher Datenhaltung und 
simpler technischer Struktur.  

Features
--------

![Screenshot](https://raw.github.com/4FriendsForum/Ffc/master/public/Screenshot.png)

* Flaches Forum (blogartige Darstellung) für alle Benutzer zugänglich
* Benutzer werden händisch von einem Administrator angelegt und müssen sich anmelden
* Private Nachrichten zwischen einzelnen Benutzern möglich
* Eigene Notizen zum eigenen Gebrauch für die Benutzer
* Instant-Chat, der über ein eigenes Browserfenster losgelöst vom Forum verwendet werden kann
  * Mehrzeilige Chatnachrichten möglich
  * Hervorhebungen für URLs, Quelltext (mit spezieller Notation '/code') sowie den eigenen Benutzernamen in Chatnachrichten möglich
  * Chatnachrichten werden immer nur nach festgelegtem und einfach änderbaren Intervallen abgeholt
* Beiträge werden in einem prominenten Feld gleich oben auf einer entsprechenden Webseite eingegeben, dieses Textfeld klappt sich via CSS oder JavaScript automatisch auf, wenn man in das kleine Feld hinein klickt oder beim Bearbeiten eines Beitrages
* Die Webseite kann sich über Javascript automatisch innerhalb eines vom Benutzer festgelegten Zeitintervalles (Default 3 Minuten) neu laden, sobald sie im Hintergrund ist und kein Text im Beitragstextfeld eingegeben wurde
* Das Forum kann mit einem einzigen Kommando eingerichtet werden, wobei ein initialer Administratoraccount sofort mit angelegt wird für die weiterführende Konfiguration
* Das Forum arbeitet innerhalb eines festgelegten Verzeichnisses
* Dateien für Uploads und Avatare werden in Unterverzeichnissen abgelegt
* Alle Benutzerdaten, Foreneinstellungen und Beiträge werden in einer SQLite-Datenbank innerhalb des festgelegten Verzeichnisses abgelegt
* Das festgelegte Forenverzeichnis ist transparent und portabel
* Forenbeiträge werden in Themen sortiert, die jeder Benutzer frei anlegen kann
* Themenüberschriften können frei vom Benutzer, der das Thema angelegt hat, geändert werden
* Wird eine Themenüberschrift in ein bereits existierendes Thema geändert, dann werden die Beiträge in dieses andere Thema verschoben
* Themen können vom Benutzer ignoriert werden, dann werden die nicht mehr hervor gehoben, wenn neue Beiträge von anderen Benutzern erstellt werden in dem Thema
* Themen können von den Benutzern auch "angeheftet" werden, dann erscheinen sie immer mit ganz oben in der Themenliste
* Foren-, Nachrichten- und Notizbeiträge enthalten primär lediglich den Text ohne Titel
* Diese Beiträge (Forum, Privatnachrichten, Notizen) haben alle intern die selbe technische Struktur
* Allen Beiträgen (Forum, Privatnachrichten, Notizen) können Dateien via Upload angehängt werden durch den Beitragsersteller
* Autoren können ihre Beiträge im Forum oder in den Notzen jederzeit löschen, nicht jedoch in den Privatnachrichten
* Uploads können jederzeit vom hochladenden Benutzer gelöscht werden
* Alle Beiträge können mit einer Art Markup versehen werden
  * Bei aktivem JavaScript im Browser bietet die Software die Möglichkeit, dieses Markup mit Hilfe von Formatierungsbuttons über dem Texteingabefeld einzutragen
* Links in Beiträgen werden automatisch erkannt und als HTML-Links dargestellt
* Bilder in Anhängen werden automatisch erkannt und als HTML-Bildervorschauen dargestellt
* Beiträge und Forenüberschriften können durchsucht werden über ein einfaches Suchfeld in der Menüzeile
* Über CSS werden Popups über die Menüzeile für Privatnachichten und Forenthemen angeboten, hier wird auch die Anzahl neuer Beiträge hinterlegt
* Ist Javascript aktiv, wird dafür gesorgt, dass die Menüleiste immer sichtbar ist, auch beim Scrollen - dann scrollt die Leiste einfach mit bei Bedarf
* Die Anzahl neuer Beiträge (Forum + Privatnachrichten) wird in Summe im Titel der HTML-Webseite (üblicherweise damit auch im Fenstertitel des Browserfensters) angezeigt, im Chat wird zusätzlich die Summer neuer Chatnachrichten mit angezeigt, wenn das Chatfenster nicht im Fokus steht
* Die Startseite für das Forum enthält eine Liste von Überschriften geordnet nach neuesten Beiträgen, ähnlich verhält es sich auch mit der Startseite für Privatnachrichten, wo die Benutzernamen gelistet werden
  * In beiden Startseiten wird jeweils die Anzahl neuer Beiträge zusammen mit einer farblichen Markierung angezeigt
  * Wahlweise kann vom Administrator für die globale Startseite (die, die auf die Themenliste verweist) auch ein bestimmtes Thema statt einer Überrsichtsseite über die Themen eingestellt werden
* Foreneinstellungen, die von Administratoren vorgenommen werden können:
  * Benutzerverwaltung mit Passwortangange, aktivieren und deaktiveren von Benutzern sowie Adminstratorenstatus setzen
  * Default-Webseitenhintergrundfarbe
  * Favoritenicon und Webseitentitel
  * Anzahl der gleichzeitig angezeigten Überschriften auf der Startseite und damit auch im Foren-Menü-Popup sowie Anzahl der Beiträge auf einer Seite
  * Für die Themenlisten kann eingestellt werden, ob aktuelle Themen auf einer Themenseite und im Menü chronologisch nach dem aktuellsten Beitrag oder alphabetisch sortiert anzeigt werden
  * Anzahl der Buchstaben die von einer URL oder von einem Thema im Foren-Menü-Popup dargestellt werden (URL-Shortener), die vollständige URL wird über ein Tooltip dargestellt
  * Es kann außerdem eine URL zu einer eigenen CSS-Stylesheet-Datei angegeben werden, welche dann nach allen anderen Stylesheetvorgaben eingebunden wird in die Webseite und über die im Bedarfsfall sämtliche Anzeigeeinstellungen für die Webseite überschrieben oder verändert werden können
* Foreneinstellungen, die von Benutzern vorgenommen werden können:
  * Passwortwechsel
  * Email-Adresse angeben (diese kann vom Administrator lediglich ausserhalb des Forums verwendet werden)
  * Hintergrundfarbe der Forenwebseite (falls der Administrator das erlaubt, was voreingestellt ist)
  * Ein Avatarbild hochladen, was neben jedem Beitrag oder Kommentar dargestellt wird (Avatar des Verfassers)
  * Minutenintervall für automatisches Neuladen der Forenwebseite, wenn diese im Hintergrund ist und kein Text eingegeben wurde (kann darüber auch deaktiviert werden, setzt man den Wert auf 0)
* Das Forum kann auch als eine Art Online-Notizblock für einen einzelnen Benutzer verwendet werden, dann sind die Funktionen der Privatnachrichten und für den Chat deaktiviert
* Das Forum verwendet die Programmiersprache Perl, das Webframework Mojolicious sowie SQLite als Datenbank, daneben wird HTML5 und CSS3 verwendet
* Die Software enthält eine umfangreiche Testsuite, in der besonderer Wert auf Datensicherheit und Zuverlässigkeit gelegt wird

Installation
============

Systemvoraussetzungen
---------------------

Folgende Software muss zunächst systemseitig zur Verfügung stehen:

* Perl Version 5.014 oder höher
* Perl-Modul Mojolicious 5:50 oder höher
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
$ FFC_DATA_PATH="Forenpfad" "script/init.pl"
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

Außerdem wird ein erster Administratoren-Account mit Zufallspasswort angelegt. Die Zugangsdaten werden auf der Kommandozeile beim Aufruf von `script/init.pl` ausgegeben und sollten notiert werden, da die weiterführende Konfiguration über diesen Account von statten geht.

Anschließend muss der Webserver so konfiguriert werden, dass das Script `script/ffc` mit der passenden Umgebungsvariable **`FFC_DATA_PATH`** als URL für diese Instanz im Web verfügbar ist. Diese Konfiguration ist von Webserver zu Webserver verschieden. Weitere Hinweise kann man auch im Internet in der Mojolicious-Dokumentation unter Deployment finden.

Unter der so eingerichteten URL sollte, wenn alles passt, anschließend das entsprechende Forum verfügbar sein. Hier kann man sich mit den vom `script/init.pl` gelieferten Daten anmelden und kann entsprechende weiterführende Konfigurationen (Foreneinstellungen und Benutzerverwaltung) unter dem Menüpunkt "Optionen" vornehmen.

Copyright und Lizenz
====================

Copyright (C) 2012-2014 by Markus Pinkert

This application is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

