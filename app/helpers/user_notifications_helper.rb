module UserNotificationsHelper

  def indent(text, by=2)
    spacer = " " * by
    result = ""
    text.each_line do |line|
      result << spacer << line
    end
    result
  end

  def correct_top_margin(html, desired)
    fragment = Nokogiri::HTML.fragment(html)
    if para = fragment.css("p:first").first
      para["style"] = "margin-top: #{desired};"
    end
    fragment.to_html.html_safe
  end

  def logo_url
    logo_url = SiteSetting.digest_logo_url
    logo_url = SiteSetting.logo_url if logo_url.blank?

    return nil if logo_url.blank?
    if logo_url !~ /http(s)?\:\/\//
      logo_url = "#{Discourse.base_url}#{logo_url}"
    end
    logo_url
  end

  def html_site_link
    "<a href='#{Discourse.base_url}'>#{@site_name}</a>"
  end

  def first_paragraph_from(html)
    doc = Nokogiri::HTML(html)

    result = ""
    doc.css('p').each do |p|
      if p.text.present?
        result << p.to_s
        return result if result.size >= 100
      end
    end
    return result unless result.blank?

    # If there is no first paragaph, return the first div (onebox)
    doc.css('div').first
  end

  def email_excerpt(html, posts_count)
    # only include 1st paragraph when more than 1 posts
    html = first_paragraph_from(html).to_s if posts_count > 1
    raw format_for_email(html)
  end

  def format_for_email(html)
    PrettyText.format_for_email(html).html_safe
  end

  def email_category(category, opts=nil)
    opts = opts || {}

    # If there is no category, bail
    return "" if category.blank?

    # By default hide uncategorized
    return "" if category.uncategorized? && !opts[:show_uncategorized]

    result = ""

    category_url = "#{Discourse.base_url}#{category.url}"

    result << "<a href='#{category_url}' style='background-color: ##{category.color}; font-size: 12px; padding: 2px 1px; font-weight: bold; margin: 0; width: 2px; white-space:nowrap;'>&nbsp;</a>"
    result << "<a href='#{category_url}' style='font-size: 12px; font-weight: bold; margin-left: 3px; color: #222;'>#{category.name}</a>"

    result.html_safe
  end
end
