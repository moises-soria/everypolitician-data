_.templateSettings = {
  evaluate: /\{\%(.+?)\%\}/g,
  interpolate: /\{\{(.+?)\}\}/g,
  escape: /\{-(.+?)-\}/g
}

var renderTemplate = function renderTemplate(templateName, data){
  data = data || {};
  var source = $('#' + templateName);
  if(source.length){
    return _.template(source.html())(data);
  } else {
    throw 'renderTemplate Error: Could not find source template with matching #' + templateName;
  }
}

var vote = function vote($choice){
  var $pairing = $choice.parents('.pairing');
  var incomingPersonID = $('.pairing__incoming .person', $pairing).attr('data-id');
  var vote = [];

  if($choice.is('.skip')) {
    // Insert a null value to indicate skip. 
    // These are removed when serializing to CSV.
    window.votes.push( [incomingPersonID, null] );
  } else {
    window.votes.push( [incomingPersonID, $choice.attr('data-uuid')] );
  }

  redrawTop();
  nextPairing($pairing);
}

var nextPairing = function nextPairing($currentPairing){
  $currentPairing.hide();
  var $nextPairing = $currentPairing.next();
  if($nextPairing.length){
    highlightExistingVotes($nextPairing);
    $nextPairing.show();
  } else {
    $('.messages').html('<h1>Reconciliation complete!</h1>'); 
    showCSVtray();
  }
}

var highlightExistingVotes = function highlightExistingVotes($pairing){
  var allVotesSoFar = allVotes();

  $('.pairing__choices .person', $pairing).each(function(){
    $(this).children('.person__already-matched').remove();

    var uuid = $(this).attr('data-uuid');
    var personAlreadyMatched = _.findWhere(allVotesSoFar, {1: uuid});

    if(personAlreadyMatched){
      // This suggested person has already been matched to an incoming person!
      // Chances are, you won't want to match again. If you do, it'll be because
      // the original match was incorrect. So we make this clear in the UI.

      // Get the details for the person they were matched to.
      var priorMatchDetails;
      _.each(window.toReconcile, function(match){
        if(match.incoming.id == personAlreadyMatched[0]){
          priorMatchDetails = match.incoming;
        }
      });

      // Show a warning.
      var warningHTML = renderTemplate('personAlreadyMatched', {
        person: priorMatchDetails ? priorMatchDetails[window.existingField] : personAlreadyMatched[0]
      });
      $(this).prepend(warningHTML);
    }
  });
}

var redrawTop = function redrawTop(){
  updateProgressBar();
  updateUndoButton();
  updateCSVtray();
  $('.messages').text('');
}

var progressAsPercentage = function progressAsPercentage(){
  if (window.toReconcile.length == 0) { return '100%' }
  return '' + (window.votes.length / $('.pairing').length * 100) + '%';
}

var updateProgressBar = function updateProgressBar(){
  $('.progress .progress-bar div').animate({ width: progressAsPercentage() }, 100);
}

var allVotes = function allVotes() { 
  return window.reconciled.concat(window.votes).concat(window.autovotes)
}

var votesAsCSV = function votesAsCSV(){
  return Papa.unparse({
    fields: ['id', 'uuid'],
    data: _.reject(allVotes(), { 1: null })
  });
}

var updateCSVtray = function updateCSVtray(){
  $('.csv').val(votesAsCSV());
}

var showCSVtray = function showCSVtray(){
  updateCSVtray();
  $('.export-csv').text('Hide CSV');
  $('.csv').slideDown(100, function(){
    $(this).select();
  });
}

var hideCSVtray = function hideCSVtray(){
  $('.export-csv').text('Show CSV');
  $('.csv').slideUp(100);
}

var toggleCSVtray = function toggleCSVtray(){
  if($('.csv').is(':visible')){
    hideCSVtray();
  } else {
    showCSVtray();
  }
}

var undo = function undo(){
  // Only continue if there's actually something to undo.
  if(window.votes.length == 0){ return; }

  // Remove last vote from window.votes,
  // and re-show the most recently hidden pairing.
  var undoneVote = window.votes.pop();
  if ($('.pairing:visible').length) { 
    $('.pairing:visible').hide().prev().show();
  } else { 
    $('.pairing').last().show();
    hideCSVtray();
  }
  redrawTop();
}

var updateUndoButton = function updateUndoButton(){
  if(window.votes.length == 0){
    $('.undo').addClass('disabled');
  } else {
    $('.undo').removeClass('disabled');
  }
}

var handleKeyPress = function handleKeyPress(e){
  // Escape
  if(e.keyCode == 27){ return toggleCSVtray(); }

  // Command-Z
  if(e.keyCode == 90 && (e.metaKey || e.ctrlKey)) { return undo(); } 
      
  // Only if there is at least one pairing left to categorise
  if($('.pairing:visible').length && $('.csv').is(':hidden')){
    // right arrow
    if(e.which == 39){ return vote($('.pairing:visible .skip')); } 

    // number key
    if(e.which > 48 && e.which < 58){
      // Avoid votes for numbers that don't exist on the page
      var $choice = $('.pairing:visible .pairing__choices .person').eq(e.which - 49);
      if($choice.length){ vote($choice); }
    }
  }
}

jQuery(function($) {

  $.each(toReconcile, function(i, match) {
    var incomingPerson = match.incoming;
    var existingPerson = match.existing[0][0];

    // TODO only do this if there's only a single exact match
    if (incomingPerson[window.incomingField].toLowerCase() == existingPerson[window.existingField].toLowerCase()) {
      window.autovotes.push( [incomingPerson.id, existingPerson.uuid] );
      return;
    }
    
    var incomingPersonFields = _.filter(Object.keys(incomingPerson), function(field) {
      return incomingPerson[field];
    });

    var existingPersonHTML = _.map(match.existing, function(existing) {
      var person = existing[0];
      person.matchStrength = Math.ceil(existing[1] * 100);
      var fields = _.intersection(incomingPersonFields, Object.keys(person));
      return renderTemplate('person', {
        person: person,
        comparison: incomingPerson,
        field: window.existingField,
        fields: fields
      });
    });

    var fields = match.existing.map(function(existing) {
      var person = existing[0];
      return Object.keys(person);
    });

    var commonFields = _.intersection(incomingPersonFields, _.uniq(_.flatten(fields)));

    var html = renderTemplate('pairing', {
      existingPersonHTML: existingPersonHTML.join("\n"),
      incomingPersonHTML: renderTemplate('person', {
        person: incomingPerson,
        comparison: null,
        field: window.incomingField,
        fields: commonFields
      })
    });
    $('.pairings').append(html);
  });

  $(document).on('click', '.pairing__choices > div', function(){
    vote($(this));
  });

  $(document).on('keydown', handleKeyPress);

  $('.undo').on('click', function(){
    undo();
  });

  $('.export-csv').on('click', function(e){
    e.stopPropagation();
    toggleCSVtray();
  });

  $('.csv').on('click', function(e){
    e.stopPropagation();
  }).on('focus', function(){
    $(this).select();
  });

  $firstPairing = $('.pairing').first();
  $firstPairing.nextAll().hide();
  highlightExistingVotes($firstPairing);

  redrawTop();
  if(toReconcile.length == 0){ $('.messages').append('<h1>Nothing to reconcile!</h1>'); }

});
