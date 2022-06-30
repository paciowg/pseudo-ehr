//= require datatables/jquery.dataTables

// optional change '//' --> '//=' to enable

// require datatables/extensions/AutoFill/dataTables.autoFill
// require datatables/extensions/Buttons/dataTables.buttons
// require datatables/extensions/Buttons/buttons.html5
// require datatables/extensions/Buttons/buttons.print
// require datatables/extensions/Buttons/buttons.colVis
// require datatables/extensions/Buttons/buttons.flash
// require datatables/extensions/ColReorder/dataTables.colReorder
// require datatables/extensions/FixedColumns/dataTables.fixedColumns
// require datatables/extensions/FixedHeader/dataTables.fixedHeader
// require datatables/extensions/KeyTable/dataTables.keyTable
// require datatables/extensions/Responsive/dataTables.responsive
// require datatables/extensions/RowGroup/dataTables.rowGroup
// require datatables/extensions/RowReorder/dataTables.rowReorder
// require datatables/extensions/Scroller/dataTables.scroller
// require datatables/extensions/Select/dataTables.select

//Global setting and initializer



// Custom filtering function which will search data in date column between two values
$.fn.dataTable.ext.search.push(
  function( settings, data, dataIndex ) {
    var min = $('#min').val();
    var max = $('#max').val();
    var date = data[0];

    var startDate   = new Date(min);
    var endDate     = new Date(max);
    var diffDate = new Date(date);
    if (
      ( min === "" && max === "" ) ||
      ( min === "" && diffDate <= endDate ) ||
      ( startDate <= diffDate   && max === "" ) ||
      ( startDate <= diffDate   && diffDate <= endDate )
    ) {
         return true;
      }
      return false;
  }
); 

$(document).on('turbolinks:load', function() {
      
    // DataTables initialisation
    var table = $('#encounters').DataTable();
 
    // Refilter the table
    $('#min, #max').on('change', function () {
        table.draw();
    });
});
