"use strict";
ffcdata.features = {};

ffcdata.features.init = function(){
    var mytitle = document.getElementsByTagName("title")[0].firstChild.data;

    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert '
                      + ( myh < 10 ? '0'+myh : myh )
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    // Chatbutton im Menü anzeigen
    var activate_chatbutton = function(){
        var chatb = document.getElementById('chatbutton');
        if ( chatb )
            chatb.className = 'menuentry chatlink';
    };

    // Auto-Refresh einsetzen
    var set_autorefresh = function(){
        ffcdata.features.autorefresh_interval = window.setInterval(function(){
            if ( !document.hasFocus()
              && (!document.getElementById('textinput')
                || document.getElementById('textinput').value === '') ) {
                ffcdata.utils.request('GET', ffcdata.counturl, null, function(res){
                    if ( res > 0 && res > ffcdata.lastcount )
                        location.reload();
                    else
                        set_titletime();
                });
            }
            else {
                return;
            }
        }, ffcdata.autorefresh * 60000 );
    };

    // Menü-Refresh einsetzen
    var exchange_menu = function(data){
        var menu = document.getElementById('menu');
        if ( !menu ) return false;
        menu.outerHTML = data;
        activate_chatbutton();
        return true;
    };
    // Request für ein neues Menü
    var update_menu = function(){
        ffcdata.utils.request('GET', ffcdata.counturl, null, function(res){
            if ( res > 0 && res > ffcdata.lastcount ) {
                ffcdata.utils.request('POST', ffcdata.menufetchurl, 
                    {pageurl: ffcdata.pageurl, queryurl: ffcdata.queryurl, controller: ffcdata.controller}, 
                    function(res){
                        updated = exchange_menu(res);
                    }, true
                );
            }
            set_titletime();
        });
    };
    var set_menurefresh = function() {
        ffcdata.features.autorefresh_interval = window.setInterval(update_menu, ffcdata.autorefresh * 60000 );
    };

    // Weitere Feature-Operationen starten
    if ( !ffcdata.singleuser )
        set_titletime();
    activate_chatbutton();
    if ( ffcdata.autorefresh > 0 && !ffcdata.utils.is_disabled() && !ffcdata.singleuser ) {
        if ( ffcdata.completerefresh ) set_autorefresh();
        else                           set_menurefresh();
    }
};

