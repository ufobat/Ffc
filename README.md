AltSimpleBoard
==============

Schnelle, leichtgewichtige, übersichtliche und unkomplizierte
Foren- und Nachrichtenplattform für eine überschaubare Anzahl
von händisch angelegten angemeldeten Teilnehmern mit klarer
und einfacher Datenhaltung und simpler technischer Struktur.

Features
--------

* Einfache Bedienung
* Schlanke Präsentation
* Ressourcenschohnende Darbietung
* Einfache klare Datenhaltung
* Alle Daten werden grundlegend in einer zentralen Tabelle erfasst
* Kein unnützer Ballast wie 
** Beitragstitel
** Überbordender Eyecandy
** Featuritis
** Avatare (ja, die sind rausgefallen=
* Datenaustauschplattform für alle Teilbereiche
* Teilbereiche:
** Diskussionsforum
*** Mit Kategorien
** Nachrichtenplattform für Privatnachrichten an einzelne Teilnehmer
** Notizen für den eigenen Bedarf

Datenstruktur
-------------

Alles ist ein Beitrag.

Beiträge haben einen Text, ein Erstelldatum und einen Urheber.

Beiträge ohne Zielperson (`to`) gelten als öffentliche Forenbeiträge.
Beiträge mit anderer Zielperson, als der Urheber ist, gelten als 
Privatnachrichten. Beiträge mit dem Urheber zusätzlich als Zielperson
gelten als eigene Notizen.

Bei Bedarf werden an die Beiträge aus dem Forum über eine Extratabelle
Kategorien angefügt. Wird das Kategoriefeld leer gelassen, gelten die
Beiträge als allgemeine Beiträge.

Benutzer können nur von bestehenden Administratorbenutzern hinzugefügt
werden, können ihr Passwort und ihre Emailadresse aber selber ändern.

Jedem Beitrag kann genau eine Datei angehängt werden ("Zwang" zur 
Archivierung). Diese Datei wird dann über einen Beitragsindex 
referenziert im Dateisystem abgelegt und kann entsprechend von allen
oder von den Zielpersonen des Beitrages abgerufen werden.

