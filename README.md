Ffc
===

Schnelle, leichtgewichtige, übersichtliche, schlanke und 
unkomplizierte Foren- und Nachrichtenplattform für eine 
überschaubare Anzahl von händisch angelegten angemeldeten 
Teilnehmern mit klarer und einfacher Datenhaltung und 
simpler technischer Struktur.  

Features
--------

![Screenshot](https://raw.github.com/4FriendsForum/Ffc/master/public/theme/Screenshot.png)

* Flaches Forum (blogartige Darstellung) für alle Benutzer zugänglich
* Benutzer werden händisch von einem Administrator angelegt und müssen sich anmelden
* Private Nachrichten zwischen einzelnen Benutzern möglich
* Eigene Notizen für die Benutzer selbst möglich
* Das Forum kann mit einem einzigen Kommando eingerichtet werden, wobei ein initialer Administratoraccount bereits angelegt wird
* Das Forum arbeitet innerhalb einesfestgelegten Verzeichnisses
* Dateien für Uploads und Avatare werden in Unterverzeichnissen abgelegt
* Alle Benutzerdaten, Foreneinstellungen und Beiträge werden in einer SQLite-Datenbank innerhalb des festgelegten Verzeichnisses abgelegt
* Das festgelegte Foremverzeichnis ist transparent und portabel
* Forenbeiträge können in von Administratoren verwalteten Kategorien abgelegt werden
* Foren-, Nachrichten- und Notizbeiträge enthalten primär lediglich den Text ohne Titel
* Diese Beiträge haben alle intern die selbe technische Struktur
* Foren- und Nachrichtenbeiträge können Kommentiert werden
* Allen Beiträgen können Dateien via Upload angehängt werden durch den Beitragsersteller
* Uploads können jederzeit gelöscht werden vom hochladenden Benutzer gelöscht werden
* Foren- und Nachrichtenbeträge können in einer flachen Struktur von allen Teilnehmern kommentiert werden
* Foren- und Nachrichtenbeiträge können vom Verfasser gelöscht und verändert werden, solange sie nicht kommentiert wurden
* Notizen können jederzeit vom Verfasser gelöscht und verändert werden
* Alle Beiträge und Kommentare können mit einer Art Markup versehen werden
* Links in Beiträgen werden automatisch erkannt und als HTML-Links dargestellt
* Bilder in Beiträgen werden automatisch erkannt und als HTML-Bildervorschauen dargestellt
* Bilder in Anhängen werden automatisch erkannt und als HTML-Bildervorschauen dargestellt
* Forenbeiträge können durchsucht werden über ein einfaches Suchfeld
* Foreneinstellungen, die von Administratoren vorgenommen werden können:
  * Benutzerverwaltung mit Passwortangange, aktivieren und deaktiveren von Benutzern sowie Adminstratorenstatus setzen
  * Webseitenhintergrundfarbe und ob Benutzer diese Farbe selber noch ändern können
  * Favoritenicon und Webseitentitel
  * Anzahl der gleichzeitig angezeigten Beiträge auf einer Seite
  * Anzahl der Buchstaben die von einer URL dargestellt werden (URL-Shortener), die vollständige URL wird über ein Tooltip dargestellt
  * Titel der allgemeinen Kategorie, die immer da ist (Kategorien werden ausgeblendet, wenn es nur diese Kategorie gibt)
* Foreneinstellungen, die von Benutzern vorgenommen werden können:
  * Passwortwechsel
  * Email-Adresse angeben (diese kann vom Administrator lediglich ausserhalb des Forums verwendet werden)
  * Hintergrundfarbe der Forenwebseite (falls der Administrator das erlaubt, was voreingestellt ist)
  * Ein Avatarbild hochladen, was neben jedem Beitrag oder Kommentar dargestellt wird (Avatar des Verfassers)
  * Schriftgröße und Breitbildanzeige (Normalanzeige ist so eine schmale blogartige Seite) können Geräteabhängig eingerichtet werden
* Das Forum verwendet folgende technische Komponenten:
  * Perl Version 5.014 oder höher
  * Mojolicious 4.0 oder höher
  * DBI Version 1.63 oder höher
  * DBD::SQLite Version 1.4 oder höher
  * SQLite Version 3.7.3 oder höher
* Die Software enthält eine umfangreiche Testsuite, in der besonderer Wert auf Datensicherheit und Zuverlässigkeit gelegt wird

Copyright und Lizenz
====================

Copyright (C) 2012-2014 by Markus Pinkert

This application is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

