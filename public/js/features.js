ffcdata.features = {};

ffcdata.features.init = function(){

    // Auto-Refresh einsetzen
    var set_autorefresh = function(){
        if ( ffcdata.utils.is_disabled() ) return;
        ffcdata.features.autorefresh_interval = window.setInterval(function(){
            if ( !document.hasFocus() 
              && (!document.getElementById('textinput') 
                || document.getElementById('textinput').value === '') ) {
                location.reload();
            }
        }, ffcdata.autorefresh * 60000 );
    };
    
    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert ' 
                      + ( myh < 10 ? '0'+myh : myh ) 
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    // Weitere Feature-Operationen starten
    set_titletime();
    if ( ffcdata.autorefresh > 0 ) 
        set_autorefresh();
};

