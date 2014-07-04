Ffc
===

Schnelle, leichtgewichtige, übersichtliche, schlanke und 
unkomplizierte Foren- und Nachrichtenplattform für eine 
überschaubare Anzahl von händisch angelegten angemeldeten 
Teilnehmern mit klarer und einfacher Datenhaltung und 
simpler technischer Struktur.  

Features
--------

![Screenshot](https://raw.github.com/4FriendsForum/Ffc/newstart/public/Screenshot.png)

* Flaches Forum (blogartige Darstellung) für alle Benutzer zugänglich
* Benutzer werden händisch von einem Administrator angelegt und müssen sich anmelden
* Private Nachrichten zwischen einzelnen Benutzern möglich
* Eigene Notizen für die Benutzer selbst möglich
* Das Forum kann mit einem einzigen Kommando eingerichtet werden, wobei ein initialer Administratoraccount bereits angelegt wird
* Das Forum arbeitet innerhalb eines festgelegten Verzeichnisses
* Dateien für Uploads und Avatare werden in Unterverzeichnissen abgelegt
* Alle Benutzerdaten, Foreneinstellungen und Beiträge werden in einer SQLite-Datenbank innerhalb des festgelegten Verzeichnisses abgelegt
* Das festgelegte Foremverzeichnis ist transparent und portabel
* Forenbeiträge werden in Themen sortiert, die jeder Benutzer frei anlegen kann
* Themenüberschriften können geändert werden
* Wird eine Themenüberschrift in ein bereits existierendes Thema geändert, dann werden die Beiträge in dieses andere Thema verschoben
* Foren-, Nachrichten- und Notizbeiträge enthalten primär lediglich den Text ohne Titel
* Diese Beiträge haben alle intern die selbe technische Struktur
* Allen Beiträgen können Dateien via Upload angehängt werden durch den Beitragsersteller
* Uploads können jederzeit gelöscht werden vom hochladenden Benutzer gelöscht werden
* Foren- und Nachrichtenbeträge können in einer flachen Struktur von allen Teilnehmern kommentiert werden
* Notizen können jederzeit vom Verfasser gelöscht und verändert werden
* Alle Beiträge können mit einer Art Markup versehen werden
* Links in Beiträgen werden automatisch erkannt und als HTML-Links dargestellt
* Bilder in Anhängen werden automatisch erkannt und als HTML-Bildervorschauen dargestellt
* Beiträge und Forenüberschriften können durchsucht werden über ein einfaches SuchfeldA in der Menüzeile
* Foreneinstellungen, die von Administratoren vorgenommen werden können:
  * Benutzerverwaltung mit Passwortangange, aktivieren und deaktiveren von Benutzern sowie Adminstratorenstatus setzen
  * Webseitenhintergrundfarbe und ob Benutzer diese Farbe selber noch ändern können
  * Favoritenicon und Webseitentitel
  * Anzahl der gleichzeitig angezeigten Beiträge auf einer Seite
  * Anzahl der Buchstaben die von einer URL dargestellt werden (URL-Shortener), die vollständige URL wird über ein Tooltip dargestellt
* Foreneinstellungen, die von Benutzern vorgenommen werden können:
  * Passwortwechsel
  * Email-Adresse angeben (diese kann vom Administrator lediglich ausserhalb des Forums verwendet werden)
  * Hintergrundfarbe der Forenwebseite (falls der Administrator das erlaubt, was voreingestellt ist)
  * Ein Avatarbild hochladen, was neben jedem Beitrag oder Kommentar dargestellt wird (Avatar des Verfassers)
  * Schriftgröße und Breitbildanzeige (Normalanzeige ist so eine schmale blogartige Seite) können Geräteabhängig eingerichtet werden
* Das Forum verwendet die Programmiersprache Perl, das Webframework Mojolicious sowie SQLite als Datenbank
* Die Software enthält eine umfangreiche Testsuite, in der besonderer Wert auf Datensicherheit und Zuverlässigkeit gelegt wird

Installation
============

Softwareinstallation
--------------------

Die Software muss in ein Verzeichnis ausgecheckt oder kopiert werden, in dem der Webserver ausführenden Zugriff auf die `Datei script/ffc` sowie lesenden Zugriff auf die Dateien unterhalb der Verzeichnisse `lib`, `public` und `templates` erhält. In diesem Verzeichnis befinden sich die Programmdateien der Software für alle Instanzen des Systems.

Die vorrausgesetzten technischen Komponenten müssen installiert werden:  

* Perl Version 5.014 oder höher
* Mojolicious 4.0 oder höher
* DBI Version 1.63 oder höher
* DBD::SQLite Version 1.4 oder höher
* SQLite Version 3.7.3 oder höher

Installation einer neuen Instanz (eigenständiges Forum)
--------------------------------------------------------

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

