$(() => {
  update_splasch_code_selection_by_category();
});

const update_splasch_code_selection_by_category = function () {
  codes = $('#splasch_observation_code').html();

  $('#splasch_observation_category').change(function() {
    category = $('#splasch_observation_category :selected').val();
    options = $(codes).filter("optgroup[label='" + category + "']").html();
    if (options) {
      $('#splasch_observation_code').html(options);
    } else {
      $('#splasch_observation_code').empty();
    }
  });
}
