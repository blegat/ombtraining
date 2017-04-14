#encoding: utf-8
# == Schema Information
#
# Table name: faketchatmessagefiles
#
#  id                :integer          not null, primary key
#  tchatmessage_id        :integer
#  file_file_name    :string(255)
#  file_content_type :string(255)
#  file_file_size    :integer
#  file_updated_at   :datetime         not null
#

class Faketchatmessagefile < ActiveRecord::Base
  # attr_accessible :file_file_name, :file_content_type, :file_file_size, :file_updated_at, :message_id

  # BELONGS_TO, HAS_MANY

  belongs_to :tchatmessage
end
