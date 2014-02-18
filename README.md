Ffc
===

Schnelle, leichtgewichtige, übersichtliche, schlanke und 
unkomplizierte Foren- und Nachrichtenplattform für eine 
überschaubare Anzahl von händisch angelegten angemeldeten 
Teilnehmern mit klarer und einfacher Datenhaltung und 
simpler technischer Struktur.  

Features
--------

![Screenshot](https://raw.github.com/4FriendsForum/Ffc/master/doc/Screenshot.png)

* Grundlegende Aspekte:
  * Stabilität
  * Datensicherheit
  * Vertraulichkeit
  * Einfache schnell zugängliche Bedienung
  * Schlanke Präsentation
  * Ressourcenschohnende Darbietung
  * Präsentation eher wie ein Blog aufgemacht
  * Einfache klare Datenhaltung (alle Daten werden grundlegend in einer zentralen Tabelle erfasst)
  * Benutzeranmeldung für die Arbeit mit dem System ist erforderlich
  * Benutzer müssen von einem Administrator angelegt werden und können sich nicht selber registrieren
  * Umfangreiche Testsuite mit starkem Fokus auf Datensicherheit (wer darf was online sehen)
* Vermeiden von Ballast und Ablenkungen, Focus auf die Textbeiträge
  * Beitragstitel
  * Überbordender Eyecandy
  * Featuritis
  * Bedienung ist komplett ohne Javascript möglich
* Teilbereiche:
  * Diskussionsforum mit (optionalen) Kategorien
  * Nachrichtenplattform für Privatnachrichten an einzelne Teilnehmer
  * Notizen für den eigenen Bedarf
* Weiterführende Features:
  * Kategorien werden fest in der Datenbank angelegt
  * Beiträge erstellen, ändern und löschen
  * Markierungen und Anzeige der Anzahl neuer Beiträge in den Kategorien und in den Teilbereichen
  * Dateiaustausch (Anhänge an Beiträge hinzufügen und entfernen)
  * Benutzeravatarbildchen
  * Optionale Anzeigethemen zur Auswahl mit Voreinstellungsmöglichkeit über die Anwendungskonfiguration
  * Anzeige für kleine Mobilgeräte über einen Link auf jeder Seite umschalten für das Gerät
  * Suche in Beiträgen über einfaches Suchfeld
  * Benutzer können deaktiviert werden
  * Benutzer können Administratoren sein (für Benutzerverwaltung)
  * Textformatierung bei der Anzeige
    * Links werden als HTML-Links dargestellt
    * Bilder werden als eine Art Thumbnail eingeblendet (kann in den Optionen geändert werden)
    * Textsmileys werden durch Bildchen ersetzt (kann in den Optionen geändert werden)
    * Einfache Textauszeichnung: +fett+, ~kursiv~, _unterstrichen_, -durchgestrichen-, !wichtig!, *Gesten*, "Zitate"
    * Footerlinks können in der Konfiguration festgelegt werden
    * MySQL und SQLite wird unterstützt
  * Optionsdialog
    * Anzeige von Bildern, Avataren und Smileys kann in den Optionen abgeschalten werden
    * Thema kann ausgewählt werden (kann vom Administrator unterbunden werden in der Konfiguration)
    * Hintergrundfarbe kann ausgewählt werden (kann vom Administrator unterbunden werden in der Konfiguration, funktioniert nur bei Themen ohne Hintergrundbilder oder mit Transparenzen im Hintergrundbild)
    * Schriftgrößeneinstellung kann in mehreren Stufen geändert werden
    * Emailadresse kann angegeben werden
    * Passwort kann geändert werden
    * Kategorien können vom Benutzer wahlweise ausgeblendet werden
    * Administrationseinstellungen (nur für Administratoren verfügbar)
      * Benutzer anlegen
      * Benutzer aktivieren und deaktivieren
      * Benutzer als Administrator (Benutzerverwaltung) setzen oder dieses Recht entziehen
      * Benutzerpassworte ändern

Datenstruktur
-------------

Alles ist ein Beitrag.

Beiträge haben einen Text, ein Erstelldatum und einen Urheber.

Beiträge ohne Zielperson (```to```) gelten als öffentliche Forenbeiträge.
Beiträge mit anderer Zielperson, als der Urheber ist, gelten als 
Privatnachrichten. Beiträge mit dem Urheber zusätzlich als Zielperson
gelten als eigene Notizen.

Bei Bedarf werden an die Beiträge aus dem Forum über eine Extratabelle
Kategorien angefügt. Wird das Kategoriefeld leer gelassen, gelten die
Beiträge als allgemeine Beiträge.

Benutzer können nur von bestehenden Administratorbenutzern hinzugefügt
werden, können ihr Passwort und ihre Emailadresse aber selber ändern.

Jedem Beitrag kann genau eine Datei angehängt werden ("Zwang" zur 
Archivierung und Komprimierung). Diese Datei wird dann über einen
Beitragsindex referenziert im Dateisystem abgelegt und kann entsprechend
von allen oder von den Zielpersonen des Beitrages abgerufen werden.

Copyright und Lizenz
====================

Copyright (C) 2012-2013 by Markus Pinkert

This application is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

