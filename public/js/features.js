"use strict";
/************************************************************************
 * Start der Initialiserung von Features
 ************************************************************************/
ffcdata.features = {};
ffcdata.features.init = function(){

    /************************************************************************
     * Webseitentitel anpassen
     ************************************************************************/
    var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
    // Titel aktualisieren
    var set_title = function(cnt){
        document.getElementsByTagName("title")[0].firstChild.data
            = ffcdata.title[0] + cnt + ffcdata.title[1];
        set_titletime();
    };
    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert '
                      + ( myh < 10 ? '0'+myh : myh )
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    /************************************************************************
     * Chat-Button bei Bedarf im Menü aktivieren
     ************************************************************************/
    var activate_chatbutton = function(){
        var chatb = document.getElementById('chatbutton');
        if ( chatb )
            chatb.className = 'menuentry chatlink';
    };

    /************************************************************************
     * Auto-Refresh der gesamten Seite bei Bedarf aktivieren
     ************************************************************************/
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

    /************************************************************************
     * Auto-Refresh nur für das Menü und den Titel bei Bedarf aktivieren
     ************************************************************************/
    var set_menurefresh = function(){
        ffcdata.features.autorefresh_interval = window.setInterval(function(){
            ffcdata.utils.request('GET', ffcdata.counturl, null, function(res){
                if ( res > 0 && res > ffcdata.lastcount ) {
                    ffcdata.utils.request('POST', ffcdata.menufetchurl, 
                        {pageurl: ffcdata.pageurl, queryurl: ffcdata.queryurl, controller: ffcdata.controller}, 
                        function(res){
                            var menu = document.getElementById('menu');
                            if ( !menu ) return false;
                            menu.outerHTML = res;
                            activate_chatbutton();
                            return true;
                        }, true
                    );
                }
                set_title();
            });
        }, ffcdata.autorefresh * 60000 );
    };

    /************************************************************************
     * Features initial aktiveren
     ************************************************************************/
    if ( !ffcdata.singleuser )
        set_titletime();
    activate_chatbutton();
    if ( ffcdata.autorefresh > 0 && !ffcdata.utils.is_disabled() && !ffcdata.singleuser ) {
        if ( ffcdata.completerefresh ) set_autorefresh();
        else                           set_menurefresh();
    }
};

