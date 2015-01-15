ffcdata.utils = {};

ffcdata.utils.init = function(){
    // Browser-Shortcomings ausgleichen
    if ( !document.hasFocus ) {
        document.hasFocus = function() {
            var hfocus = true;
            window.onfocus = function() { hfocus = true;  };
            window.onblur  = function() { hfocus = false; };
            return function() { return hfocus; };
        }();
    }

    // Erweiterte Javascript-Features auf Geräten mit kleinen Bildschirmen deaktivieren
    var features_disabled = undefined;
    ffcdata.utils.is_disabled = function(){

        if ( features_disabled !== undefined )
            return features_disabled;

        if ( window.matchMedia('(max-device-width: 800px)').matches ) 
            features_disabled = true;
        else
            features_disabled = false;

        return features_disabled;
    };

}
