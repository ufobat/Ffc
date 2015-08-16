Features
========

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
* Themen mit neuen Beiträgen können aus der Themenliste über einen Link als "gelesen" markiert werden, was bedeutet, dass der Benutzer "gesehen" hat, dass neue Beiträge da sind, auf diese aber nicht näher eingehen wollte
* Für die Themenlisten kann eingestellt werden, ob aktuelle Themen auf einer Themenseite und im Menü chronologisch nach dem aktuellsten Beitrag oder alphabetisch sortiert anzeigt werden
* Anzahl der gleichzeitig angezeigten Überschriften auf der Startseite und damit auch im Foren-Menü-Popup ändern
* Anzahl der gleichzeitig auf einer Seite angezeigten Beiträge ändern
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
  * Anzahl der Buchstaben die von einer URL oder von einem Thema im Foren-Menü-Popup dargestellt werden (URL-Shortener), die vollständige URL wird über ein Tooltip dargestellt
  * Es kann außerdem eine URL zu einer eigenen CSS-Stylesheet-Datei angegeben werden, welche dann nach allen anderen Stylesheetvorgaben eingebunden wird in die Webseite und über die im Bedarfsfall sämtliche Anzeigeeinstellungen für die Webseite überschrieben oder verändert werden können
* Es ist über einen Link möglich, eine kurze schnörkellose Auflistung von Themen mit neuen Beiträgen oder Benutzern, von denen neue Privatnachrichten gekommen sind, mit entsprechenden Links dahinter anzeigen zu lassen
  * Alternativ kann diese Liste (komplett mit alle Benutzern und aktuellen Themen der ersten Seite) auch über JSON geliefert werden
* Foreneinstellungen, die von Benutzern vorgenommen werden können:
  * Passwortwechsel
  * Email-Adresse angeben (diese kann vom Administrator lediglich ausserhalb des Forums verwendet werden)
  * Hintergrundfarbe der Forenwebseite (falls der Administrator das erlaubt, was voreingestellt ist)
  * Ein Avatarbild hochladen, was neben jedem Beitrag oder Kommentar dargestellt wird (Avatar des Verfassers)
  * Minutenintervall für automatisches Neuladen der Forenwebseite, wenn diese im Hintergrund ist und kein Text eingegeben wurde (kann darüber auch deaktiviert werden, setzt man den Wert auf 0)
* Das Forum kann auch als eine Art Online-Notizblock für einen einzelnen Benutzer verwendet werden, dann sind die Funktionen der Privatnachrichten und für den Chat deaktiviert
* Das Forum verwendet die Programmiersprache Perl, das Webframework Mojolicious sowie SQLite als Datenbank, daneben wird HTML5 und CSS3 verwendet
* Technische Designziele sind die einfach strukturierte Datenhaltung sowie eine schlanke, einfache und schnelle Softwarebasis
* Die Software enthält eine umfangreiche Testsuite, in der besonderer Wert auf Datensicherheit und Zuverlässigkeit gelegt wird

