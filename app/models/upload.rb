require "digest/sha1"
require_dependency "image_sizer"
require_dependency "file_helper"
require_dependency "validators/upload_validator"

class Upload < ActiveRecord::Base
  belongs_to :user

  has_many :post_uploads, dependent: :destroy
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with ::Validators::UploadValidator

  def thumbnail(width = self.width, height = self.height)
    optimized_images.find_by(width: width, height: height)
  end

  def has_thumbnail?(width, height)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height)
    return unless SiteSetting.create_thumbnails?
    thumbnail = OptimizedImage.create_for(self, width, height, allow_animation: SiteSetting.allow_animated_thumbnails)
    if thumbnail
      optimized_images << thumbnail
      self.width = width
      self.height = height
      save!
    end
  end

  def destroy
    Upload.transaction do
      Discourse.store.remove_upload(self)
      super
    end
  end

  def extension
    File.extname(original_filename)
  end

  # options
  #   - content_type
  #   - origin
  def self.create_for(user_id, file, filename, filesize, options = {})
    # compute the sha
    sha1 = Digest::SHA1.file(file).hexdigest
    # check if the file has already been uploaded
    upload = Upload.find_by(sha1: sha1)
    # delete the previously uploaded file if there's been an error
    if upload && upload.url.blank?
      upload.destroy
      upload = nil
    end
    # create the upload
    unless upload
      # initialize a new upload
      upload = Upload.new(
        user_id: user_id,
        original_filename: filename,
        filesize: filesize,
        sha1: sha1,
        url: ""
      )
      # trim the origin if any
      upload.origin = options[:origin][0...1000] if options[:origin]

      # check the size of the upload
      if FileHelper.is_image?(filename)
        if SiteSetting.max_image_size_kb > 0 && filesize >= SiteSetting.max_image_size_kb.kilobytes
          upload.errors.add(:base, I18n.t("upload.images.too_large", max_size_kb: SiteSetting.max_image_size_kb))
        else
          # deal with width & height for images
          upload = Upload.resize_image(filename, file, upload)
        end
      else
        if SiteSetting.max_attachment_size_kb > 0 && filesize >= SiteSetting.max_attachment_size_kb.kilobytes
          upload.errors.add(:base, I18n.t("upload.attachments.too_large", max_size_kb: SiteSetting.max_attachment_size_kb))
        end
      end

      # make sure there is no error
      return upload unless upload.errors.empty?

      # create a db record (so we can use the id)
      return upload unless upload.save

      # store the file and update its url
      url = Discourse.store.store_upload(file, upload, options[:content_type])
      if url.present?
        upload.url = url
        upload.save
      else
        upload.errors.add(:url, I18n.t("upload.store_failure", { upload_id: upload.id, user_id: user_id }))
      end
    end

    # return the uploaded file
    upload
  end

  def self.resize_image(filename, file, upload)
    begin
      if filename =~ /\.svg$/i
        svg = Nokogiri::XML(file).at_css("svg")
        width, height = svg["width"].to_i, svg["height"].to_i
        if width == 0 || height == 0
          upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
        else
          upload.width, upload.height = ImageSizer.resize(width, height)
        end
      else
        # fix orientation first
        Upload.fix_image_orientation(file.path)
        # retrieve image info
        image_info = FastImage.new(file, raise_on_failure: true)
          # compute image aspect ratio
        upload.width, upload.height = ImageSizer.resize(*image_info.size)
      end
      # make sure we're at the beginning of the file
      # (FastImage and Nokogiri move the pointer)
      file.rewind
    rescue FastImage::ImageFetchFailure
      upload.errors.add(:base, I18n.t("upload.images.fetch_failure"))
    rescue FastImage::UnknownImageType
      upload.errors.add(:base, I18n.t("upload.images.unknown_image_type"))
    rescue FastImage::SizeNotFound
      upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    end

    upload
  end

  def self.get_from_url(url)
    return if url.blank?
    # we store relative urls, so we need to remove any host/cdn
    url = url.gsub(/^#{Discourse.asset_host}/i, "") if Discourse.asset_host.present?
    Upload.find_by(url: url) if Discourse.store.has_been_uploaded?(url)
  end

  def self.fix_image_orientation(path)
    `convert #{path} -auto-orient #{path}`
  end

end

# == Schema Information
#
# Table name: uploads
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  original_filename :string(255)      not null
#  filesize          :integer          not null
#  width             :integer
#  height            :integer
#  url               :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sha1              :string(40)
#  origin            :string(1000)
#  retain_hours      :integer
#
# Indexes
#
#  index_uploads_on_id_and_url  (id,url)
#  index_uploads_on_sha1        (sha1) UNIQUE
#  index_uploads_on_url         (url)
#  index_uploads_on_user_id     (user_id)
#
