require_dependency 'sass/discourse_sass_compiler'
require_dependency 'sass/discourse_stylesheets'
require_dependency 'distributed_cache'

class SiteCustomization < ActiveRecord::Base
  ENABLED_KEY = '7e202ef2-56d7-47d5-98d8-a9c8d15e57dd'
  @cache = DistributedCache.new('site_customization')

  before_create do
    self.enabled ||= false
    self.key ||= SecureRandom.uuid
    true
  end

  def compile_stylesheet(scss)
    DiscourseSassCompiler.compile(scss, 'custom')
  rescue => e
    puts e.backtrace.join("\n") unless Sass::SyntaxError === e
    raise e
  end

  before_save do
    ['stylesheet', 'mobile_stylesheet'].each do |stylesheet_attr|
      if self.send("#{stylesheet_attr}_changed?")
        begin
          self.send("#{stylesheet_attr}_baked=", compile_stylesheet(self.send(stylesheet_attr)))
        rescue Sass::SyntaxError => e
          self.send("#{stylesheet_attr}_baked=", DiscourseSassCompiler.error_as_css(e, "custom stylesheet"))
        end
      end
    end
  end

  after_save do
    remove_from_cache!
    if stylesheet_changed? || mobile_stylesheet_changed?
      MessageBus.publish "/file-change/#{key}", SecureRandom.hex
      MessageBus.publish "/file-change/#{SiteCustomization::ENABLED_KEY}", SecureRandom.hex
    end
    MessageBus.publish "/header-change/#{key}", header if header_changed?
    MessageBus.publish "/footer-change/#{key}", footer if footer_changed?
    DiscourseStylesheets.cache.clear
  end

  after_destroy do
    remove_from_cache!
  end

  def self.enabled_key
    ENABLED_KEY.dup << RailsMultisite::ConnectionManagement.current_db
  end

  def self.enabled_stylesheet_contents(target=:desktop)
    @cache["enabled_stylesheet_#{target}"] ||= where(enabled: true)
      .order(:name)
      .pluck(target == :desktop ? :stylesheet_baked : :mobile_stylesheet_baked)
      .compact
      .join("\n")
  end

  def self.stylesheet_contents(key, target)
    if key == ENABLED_KEY
      enabled_stylesheet_contents(target)
    else
      where(key: key)
        .pluck(target == :mobile ? :mobile_stylesheet_baked : :stylesheet_baked)
        .first
    end
  end

  def self.custom_stylesheet(preview_style=nil, target=:desktop)
    preview_style ||= ENABLED_KEY
    if preview_style == ENABLED_KEY
      stylesheet_link_tag(ENABLED_KEY, target, enabled_stylesheet_contents(target))
    else
      lookup_field(preview_style, target, :stylesheet_link_tag)
    end
  end

  %i{header top footer head_tag body_tag}.each do |name|
    define_singleton_method("custom_#{name}") do |preview_style=nil, target=:desktop|
      preview_style ||= ENABLED_KEY
      lookup_field(preview_style, target, name)
    end
  end

  def self.lookup_field(key, target, field)
    return if key.blank?

    cache_key = key + target.to_s + field.to_s;

    lookup = @cache[cache_key]
    return lookup.html_safe if lookup

    styles = if key == ENABLED_KEY
      order(:name).where(enabled:true).to_a
    else
      [find_by(key: key)].compact
    end

    val = if styles.present?
      styles.map do |style|
        lookup = target == :mobile ? "mobile_#{field}" : field
        style.send(lookup)
      end.compact.join("\n")
    end

    (@cache[cache_key] = val || "").html_safe
  end

  def self.remove_from_cache!(key, broadcast = true)
    MessageBus.publish('/site_customization', key: key) if broadcast
    clear_cache!
  end

  def self.clear_cache!
    @cache.clear
  end

  def remove_from_cache!
    self.class.remove_from_cache!(self.class.enabled_key)
    self.class.remove_from_cache!(key)
  end

  def mobile_stylesheet_link_tag
    stylesheet_link_tag(:mobile)
  end

  def stylesheet_link_tag(target=:desktop)
    content = target == :mobile ? mobile_stylesheet : stylesheet
    SiteCustomization.stylesheet_link_tag(key, target, content)
  end

  def self.stylesheet_link_tag(key, target, content)
    return "" unless content.present?

    hash = Digest::MD5.hexdigest(content)
    link_css_tag "/site_customizations/#{key}.css?target=#{target}&v=#{hash}"
  end

  def self.link_css_tag(href)
    href = (GlobalSetting.cdn_url ? GlobalSetting.cdn_url : Discourse.base_url) + "#{href}&__ws=#{Discourse.current_hostname}"
    %Q{<link class="custom-css" rel="stylesheet" href="#{href}" type="text/css" media="all">}.html_safe
  end
end

# == Schema Information
#
# Table name: site_customizations
#
#  id                      :integer          not null, primary key
#  name                    :string(255)      not null
#  stylesheet              :text
#  header                  :text
#  user_id                 :integer          not null
#  enabled                 :boolean          not null
#  key                     :string(255)      not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  stylesheet_baked        :text             default(""), not null
#  mobile_stylesheet       :text
#  mobile_header           :text
#  mobile_stylesheet_baked :text
#  footer                  :text
#  mobile_footer           :text
#
# Indexes
#
#  index_site_customizations_on_key  (key)
#
