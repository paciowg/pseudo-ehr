// you need a .bootstrap-toggle class for all bootstrap-toggle checkboxes
(function($) {

    $(document).on('turbolinks:load', function() { 
        $('input[type="checkbox"].bootstrap-toggle').bootstrapToggle();
        $('div.toggle > div.toggle-group > span.toggle-handle').addClass('bg-light');
    });
 
})(jQuery);