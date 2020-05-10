(function($) {

    window.landing = {

        patientFilter: function() {
            dirtySearchTerms = $("input.patient-filter").val().split(/\s+/);
            searchTerms = dirtySearchTerms.filter(function(el) { return el; });
            if (searchTerms.length == 0) {
                $(".patient-option").each(function() {
                    if (!$(this).hasClass('show')) $(this).addClass('show');
                });
            } else {
                $('.patient-option').each(function() {
                    text = $(this).text();
                    matches = true;
                    searchTerms.forEach(function(term) {
                        if (matches) matches = text.toUpperCase().includes(term.toUpperCase());
                    });
                    if (matches) {
                        if (!$(this).hasClass('show')) $(this).addClass('show');
                    } else {
                        $(this).removeClass('show');
                    }
                });
            }
        },

        patientFilterListener: function() {
            $("input.patient-filter").on("keyup", window.landing.patientFilter);
        }

    };

    $(document).on('turbolinks:load', window.landing.patientFilterListener);
 
})(jQuery);