"use strict";
/************************************************************************
 * Start der Initialiserung von Features
 ************************************************************************/
ffcdata.features = {};
ffcdata.features.fileuploadchange = function(it){};
ffcdata.features.hidemessagebox   = function(it){};
ffcdata.features.init = function(){

    /************************************************************************
     * Webseitentitel anpassen
     ************************************************************************/
    var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
    // Titel aktualisieren
    var set_title = function(cnt){
        mytitle = ffcdata.title[0] + cnt + ffcdata.title[1];
        ffcdata.lastcount = cnt;
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
        var chats = document.getElementById('menuchatseparator');
        if ( chatb )
            chatb.className = 'menuentry chatlink';
        if ( chats )
            chats.className = 'menubarseparator';
    };

    /************************************************************************
     * Kompletter Auto-Refresh der gesamten Seite 
     ************************************************************************/
    var auto_refresh_complete = function(){
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
    };

    /************************************************************************
     * Auto-Refresh-Funktion nur für das Menü und den Titel
     ************************************************************************/
    var auto_refresh_menu = function(){
        ffcdata.utils.request('POST', ffcdata.fetchurl, 
            {pageurl: ffcdata.pageurl, queryurl: ffcdata.queryurl, controller: ffcdata.controller}, 
            function(res){
                set_title(res[0]);
                var menu = document.getElementById('menu');
                if ( menu ) menu.outerHTML = res[1];
                var chatbutton = document.getElementById('chatbutton');
                if ( chatbutton ) {
                    chatbutton.outerHTML = res[2];
                    activate_chatbutton();
                }
                return true;
            }
        );
    };

    /************************************************************************
     * Auto-Refresh-Funktion nur für das Menü und den Titel
     ************************************************************************/
    var auto_refresh = function(){
        if   ( ffcdata.completerefresh ) { auto_refresh_complete() } 
        else                             { auto_refresh_menu()     }
    };

    /************************************************************************
     * Auto-Refresh der gesamten Seite bei Bedarf aktivieren
     ************************************************************************/
    var set_autorefresh = function(){
        ffcdata.features.autorefresh_interval = window.setInterval(
            auto_refresh_complete, ffcdata.autorefresh * 60000 );
    };

    /************************************************************************
     * Auto-Refresh nur für das Menü und den Titel bei Bedarf aktivieren
     ************************************************************************/
    var set_menurefresh = function(){
        ffcdata.features.autorefresh_interval 
            = window.setInterval(auto_refresh, ffcdata.autorefresh * 60000 );
    };

    /************************************************************************
     * Auto-Refresh für das Menü, wenn das Themen-Fenster den Fokus erhält
     ************************************************************************/
    var set_focusrefresh = function(){
        window.onfocus = auto_refresh;
    };

    /************************************************************************
     * Dateihochladefelder ergänzen
     ************************************************************************/
    var set_upload_multi = function(){
        var uibox = document.getElementById('uploadinputsbox');
        if ( !uibox ) return;
        var uifield = document.getElementById('uploadinputfield');
        if ( !uifield ) return;
        var iter = 1;
        ffcdata.features.fileuploadchange = function(it){
            var val = it.value;
            if ( !val || val === '' || iter > 42 ) return;
            it.onchange = null;
            var uifieldnew = uifield.cloneNode(true);
            uifieldnew.firstChild.value = '';
            uibox.appendChild(uifieldnew);
            iter++;
        };
    };

    /************************************************************************
     * Benachrichtigungsfenster mittels Klick verschwinden lassen
     ************************************************************************/
    var enable_hidemessagebox = function(){
        ffcdata.features.hidemessagebox = function(it){
            if( !it ) return;
            it.style.display = 'none';
        };
    }

    /************************************************************************
     * Features initial aktiveren
     ************************************************************************/
    var enable_strg_s = function() {
        var tif = document.getElementById('textinputform'); 
        if ( tif ) {
            // console.log(tif);
            tif.onkeydown = function(ev) {
                // console.log(ev.keyCode + '-' + ev.ctrlKey);
                if (ev.keyCode == 83 && ev.ctrlKey) {
                    tif.submit();
                    ev.preventDefault();
                }
            };
        }
    };

    /************************************************************************
     * Features initial aktiveren
     ************************************************************************/
    if ( !ffcdata.singleuser )
        set_titletime();
    activate_chatbutton();
    if ( ffcdata.autorefresh > 0 && !ffcdata.utils.is_disabled() && !ffcdata.singleuser ) {
        set_menurefresh();
        set_focusrefresh();
    }
    set_upload_multi();
    enable_hidemessagebox();
    enable_strg_s();
};

