/**
  This mixin provides an 'ajax' method that can be used to perform ajax requests that
  respect Discourse paths and the run loop.

  @class Discourse.Ajax
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.Ajax = Em.Mixin.create({

  /**
    Our own $.ajax method. Makes sure the .then method executes in an Ember runloop
    for performance reasons. Also automatically adjusts the URL to support installs
    in subfolders.

    @method ajax
  **/
  ajax: function() {
    var url, args;

    if (arguments.length === 1) {
      if (typeof arguments[0] === "string") {
        url = arguments[0];
        args = {};
      } else {
        args = arguments[0];
        url = args.url;
        delete args.url;
      }
    } else if (arguments.length === 2) {
      url = arguments[0];
      args = arguments[1];
    }

    if (args.success) {
      Ember.Logger.error("DEPRECATION: Discourse.ajax should use promises, received 'success' callback");
    }
    if (args.error) {
      Ember.Logger.error("DEPRECATION: Discourse.ajax should use promises, received 'error' callback");
    }

    var performAjax = function(resolve, reject) {
      var oldSuccess = args.success;
      args.success = function(xhr) {
        Ember.run(null, resolve, xhr);
        if (oldSuccess) oldSuccess(xhr);
      };

      var oldError = args.error;
      args.error = function(xhr, textStatus) {

        // note: for bad CSRF we don't loop an extra request right away.
        //  this allows us to eliminate the possibility of having a loop.
        if (xhr.status === 403 && xhr.responseText === "['BAD CSRF']") {
          Discourse.Session.current().set('csrfToken', null);
        }

        // If it's a parsererror, don't reject
        if (xhr.status === 200) return args.success(xhr);

        // Fill in some extra info
        xhr.jqTextStatus = textStatus;
        xhr.requestedUrl = url;

        // TODO is this sequence correct? we are calling catch defined externally before
        // the error that was defined inline, it should probably be in reverse
        Ember.run(null, reject, xhr);
        if (oldError) oldError(xhr);
      };

      // We default to JSON on GET. If we don't, sometimes if the server doesn't return the proper header
      // it will not be parsed as an object.
      if (!args.type) args.type = 'GET';
      if (!args.dataType && args.type.toUpperCase() === 'GET') args.dataType = 'json';

      if (args.type === 'GET' && args.cache !== true) {
        args.cache = false;
      }

      $.ajax(Discourse.getURL(url), args);
    };

    // For cached pages we strip out CSRF tokens, need to round trip to server prior to sending the
    //  request (bypass for GET, not needed)
    if(args.type && args.type.toUpperCase() !== 'GET' && !Discourse.Session.currentProp('csrfToken')){
      return new Ember.RSVP.Promise(function(resolve, reject){
        $.ajax(Discourse.getURL('/session/csrf'), {cache: false})
           .success(function(result){
              Discourse.Session.currentProp('csrfToken', result.csrf);
              performAjax(resolve, reject);
           });
      });
    } else {
      return new Ember.RSVP.Promise(performAjax);
    }
  }

});
