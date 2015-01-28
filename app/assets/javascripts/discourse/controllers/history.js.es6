import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';

// This controller handles displaying of history
export default ObjectController.extend(ModalFunctionality, {
  loading: true,
  viewMode: "side_by_side",
  revisionsTextKey: "post.revisions.controls.comparing_previous_to_current_out_of_total",

  _changeViewModeOnMobile: function() {
    if (Discourse.Mobile.mobileView) { this.set("viewMode", "inline"); }
  }.on("init"),

  refresh: function(postId, postVersion) {
    this.set("loading", true);

    var self = this;
    Discourse.Post.loadRevision(postId, postVersion).then(function (result) {
      self.setProperties({ loading: false, model: result });
    });
  },

  hide: function(postId, postVersion) {
    var self = this;
    Discourse.Post.hideRevision(postId, postVersion).then(function () {
      self.refresh(postId, postVersion);
    });
  },

  show: function(postId, postVersion) {
    var self = this;
    Discourse.Post.showRevision(postId, postVersion).then(function () {
      self.refresh(postId, postVersion);
    });
  },

  createdAtDate: function() { return moment(this.get("created_at")).format("LLLL"); }.property("created_at"),

  previousVersion: function() { return this.get("current_version") - 1; }.property("current_version"),

  displayGoToFirst: function() { return this.get("current_revision") > this.get("first_revision"); }.property("current_revision", "first_revision"),
  displayGoToPrevious: function() { return this.get("previous_revision") && this.get("current_revision") > this.get("previous_revision"); }.property("current_revision", "previous_revision"),
  displayRevisions: Em.computed.gt("version_count", 2),
  displayGoToNext: function() { return this.get("next_revision") && this.get("current_revision") < this.get("next_revision"); }.property("current_revision", "next_revision"),
  displayGoToLast: function() { return this.get("current_revision") < this.get("last_revision"); }.property("current_revision", "last_revision"),

  displayShow: function() { return this.get("previous_hidden") && Discourse.User.currentProp('staff') && !this.get("loading"); }.property("previous_hidden", "loading"),
  displayHide: function() { return !this.get("previous_hidden") && Discourse.User.currentProp('staff') && !this.get("loading"); }.property("previous_hidden", "loading"),

  isEitherRevisionHidden: Em.computed.or("previous_hidden", "current_hidden"),

  hiddenClasses: function() {
    if (this.get("displayingInline")) {
      return this.get("isEitherRevisionHidden") ? "hidden-revision-either" : null;
    } else {
      var result = [];
      if (this.get("previous_hidden")) { result.push("hidden-revision-previous"); }
      if (this.get("current_hidden")) { result.push("hidden-revision-current"); }
      return result.join(" ");
    }
  }.property("previous_hidden", "current_hidden", "displayingInline"),

  displayingInline: Em.computed.equal("viewMode", "inline"),
  displayingSideBySide: Em.computed.equal("viewMode", "side_by_side"),
  displayingSideBySideMarkdown: Em.computed.equal("viewMode", "side_by_side_markdown"),

  previousCategory: function() {
    var changes = this.get("category_id_changes");
    if (changes) {
      var category = Discourse.Category.findById(changes["previous"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  }.property("category_id_changes"),

  currentCategory: function() {
    var changes = this.get("category_id_changes");
    if (changes) {
      var category = Discourse.Category.findById(changes["current"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  }.property("category_id_changes"),

  wikiDisabled: function() {
    var changes = this.get("wiki_changes");
    return changes && !changes['current'];
  }.property('wiki_changes'),

  postTypeDisabled: function () {
    var changes = this.get("post_type_changes");
    return (changes && changes['current'] !== this.site.get('post_types.moderator_action'));
  }.property("post_type_changes"),

  titleDiff: function() {
    var viewMode = this.get("viewMode");
    if (viewMode === "side_by_side_markdown") { viewMode = "side_by_side"; }
    return this.get("title_changes." + viewMode);
  }.property("viewMode", "title_changes"),

  bodyDiff: function() {
    return this.get("body_changes." + this.get("viewMode"));
  }.property("viewMode", "body_changes"),

  actions: {
    loadFirstVersion: function() { this.refresh(this.get("post_id"), this.get("first_revision")); },
    loadPreviousVersion: function() { this.refresh(this.get("post_id"), this.get("previous_revision")); },
    loadNextVersion: function() { this.refresh(this.get("post_id"), this.get("next_revision")); },
    loadLastVersion: function() { this.refresh(this.get("post_id"), this.get("last_revision")); },

    hideVersion: function() { this.hide(this.get("post_id"), this.get("current_revision")); },
    showVersion: function() { this.show(this.get("post_id"), this.get("current_revision")); },

    displayInline: function() { this.set("viewMode", "inline"); },
    displaySideBySide: function() { this.set("viewMode", "side_by_side"); },
    displaySideBySideMarkdown: function() { this.set("viewMode", "side_by_side_markdown"); }
  }
});
